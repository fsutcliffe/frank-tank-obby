/**
 * RobloxProject — Henderson's file writer for Luau scripts in Rojo projects.
 *
 * Designed for use by Henderson (Team Forge) to generate and manage
 * Luau scripts within a Rojo-based Roblox project.
 *
 * @module roblox-project
 */

const fs = require("fs/promises");
const path = require("path");
const { execSync } = require("child_process");

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Character that must not appear in any user-supplied name or folder. */
const PATH_TRAVERSAL_RE = /(?:^|[\\/])\.\.(?:[\\/]|$)/;

/**
 * Sanitise a script name: strip .lua if present, then re-append.
 * Returns { baseName, fullName } where fullName = baseName + ".lua".
 */
function sanitiseScriptName(raw) {
  if (typeof raw !== "string" || !raw) {
    throw new Error(`Invalid script name: "${raw}"`);
  }
  // Strip .lua if already present
  let base = raw.endsWith(".lua") ? raw.slice(0, -4) : raw;
  if (!base) throw new Error(`Script name resolves to empty after sanitisation`);
  return { baseName: base, fullName: base + ".lua" };
}

/** Escape string for safe shell use (StyLua formatting). */
function shellEscape(s) {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

// ─── Per-file write lock (concurrent-write safety) ─────────────────────────

const locks = new Map();

/**
 * Acquire an exclusive lock for a file path.
 * Returns a release function.  Waits if another write is in-flight.
 */
async function acquireLock(filePath) {
  // Wait until no lock exists for this path
  while (locks.has(filePath)) {
    await locks.get(filePath);
  }
  let release;
  const promise = new Promise((resolve) => {
    release = () => {
      locks.delete(filePath);
      resolve();
    };
  });
  locks.set(filePath, promise);
  return release;
}

// ─── RobloxProject class ───────────────────────────────────────────────────

class RobloxProject {
  /**
   * @param {string} projectPath - Absolute or relative path to the Rojo project root.
   */
  constructor(projectPath) {
    if (!projectPath || typeof projectPath !== "string") {
      throw new Error("projectPath is required");
    }
    this.projectPath = path.resolve(projectPath);
    this._initialised = false;
  }

  // ── Init ─────────────────────────────────────────────────────────────

  /**
   * Validate the project exists and has a valid default.project.json.
   * @returns {Promise<object>} The parsed project config.
   */
  async init() {
    let stat;
    try {
      stat = await fs.stat(this.projectPath);
    } catch {
      throw new Error(`Project path does not exist: ${this.projectPath}`);
    }
    if (!stat.isDirectory()) {
      throw new Error(`Project path is not a directory: ${this.projectPath}`);
    }

    const configPath = path.join(this.projectPath, "default.project.json");
    let config;
    try {
      const raw = await fs.readFile(configPath, "utf-8");
      config = JSON.parse(raw);
    } catch (err) {
      throw new Error(
        `Cannot read/parse default.project.json: ${err.message}`
      );
    }

    // Basic sanity: must have a "tree" key
    if (!config || typeof config.tree !== "object") {
      throw new Error(
        `default.project.json is missing the "tree" property`
      );
    }

    this._initialised = true;
    this._config = config;
    return config;
  }

  /** Guard: throw if init() hasn't been called. */
  _assertReady() {
    if (!this._initialised) {
      throw new Error("RobloxProject not initialised — call init() first");
    }
  }

  /**
   * Validate a user-supplied name or folder for path-traversal attempts.
   * Throws if it contains ".." as a path component.
   */
  _validatePathComponent(label, value) {
    if (typeof value !== "string" || !value) {
      throw new Error(`${label} must be a non-empty string`);
    }
    if (PATH_TRAVERSAL_RE.test(value)) {
      throw new Error(
        `Path traversal detected in ${label}: "${value}" is not allowed`
      );
    }
    // Also reject absolute paths or Windows drive letters
    if (path.isAbsolute(value) || /^[A-Za-z]:[\\/]/.test(value)) {
      throw new Error(
        `Absolute path or drive letter not allowed in ${label}: "${value}"`
      );
    }
  }

  /** Resolve a script's full path from name and folder. */
  _resolveScriptPath(name, folder) {
    this._validatePathComponent("name", name);
    this._validatePathComponent("folder", folder);

    const { fullName } = sanitiseScriptName(name);
    return path.join(this.projectPath, "src", folder, fullName);
  }

  /** Resolve a model.json path. */
  _resolveModelPath(name, folder) {
    this._validatePathComponent("name", name);
    this._validatePathComponent("folder", folder);

    const base = name.endsWith(".model.json")
      ? name
      : name + ".model.json";
    return path.join(this.projectPath, "src", folder, base);
  }

  // ── writeScript ──────────────────────────────────────────────────────

  /**
   * Write a .lua file to src/{folder}/{name}.lua.
   * Parent directories are created automatically.
   * Files are formatted with StyLua if available (fall back gracefully).
   *
   * @param {string} name  - Script name, e.g. "MyScript.server" → MyScript.server.lua
   * @param {string} source - Luau source code
   * @param {string} folder - Service folder under src/, e.g. "ServerScriptService"
   * @returns {Promise<string>} The absolute path written to.
   */
  async writeScript(name, source, folder) {
    this._assertReady();
    const filePath = this._resolveScriptPath(name, folder);
    const release = await acquireLock(filePath);

    try {
      // Ensure parent directory exists
      await fs.mkdir(path.dirname(filePath), { recursive: true });

      // Write source
      await fs.writeFile(filePath, source, "utf-8");

      // Attempt StyLua formatting (best-effort)
      try {
        execSync(
          `stylua ${shellEscape(filePath)}`,
          { stdio: "ignore", timeout: 10_000 }
        );
      } catch {
        // StyLua not available or failed — fall back gracefully
      }

      return filePath;
    } finally {
      release();
    }
  }

  // ── deleteScript ─────────────────────────────────────────────────────

  /**
   * Delete a script file.
   *
   * @param {string} name
   * @param {string} folder
   * @returns {Promise<boolean>} true if deleted, false if not found.
   */
  async deleteScript(name, folder) {
    this._assertReady();
    const filePath = this._resolveScriptPath(name, folder);
    const release = await acquireLock(filePath);

    try {
      await fs.unlink(filePath);
      return true;
    } catch (err) {
      if (err.code === "ENOENT") return false;
      throw err;
    } finally {
      release();
    }
  }

  // ── writeModelJson ───────────────────────────────────────────────────

  /**
   * Write a .model.json file for advanced Rojo instances.
   *
   * @param {string} name       - File name (with or without .model.json)
   * @param {object} modelData  - Rojo .model.json payload
   * @param {string} folder     - Service folder under src/
   * @returns {Promise<string>} The absolute path written to.
   */
  async writeModelJson(name, modelData, folder) {
    this._assertReady();
    const filePath = this._resolveModelPath(name, folder);
    const release = await acquireLock(filePath);

    try {
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(
        filePath,
        JSON.stringify(modelData, null, "\t"),
        "utf-8"
      );
      return filePath;
    } finally {
      release();
    }
  }

  // ── getScriptContent ─────────────────────────────────────────────────

  /**
   * Read back a script's content.
   *
   * @param {string} name
   * @param {string} folder
   * @returns {Promise<string>} The file contents.
   * @throws {Error} if the file does not exist.
   */
  async getScriptContent(name, folder) {
    this._assertReady();
    const filePath = this._resolveScriptPath(name, folder);
    return await fs.readFile(filePath, "utf-8");
  }

  // ── listScripts ──────────────────────────────────────────────────────

  /**
   * List all .lua files in a folder under src/.
   *
   * @param {string} folder - Service folder name.
   * @returns {Promise<string[]>} Array of script base names (without .lua extension).
   */
  async listScripts(folder) {
    this._assertReady();
    this._validatePathComponent("folder", folder);

    const dirPath = path.join(this.projectPath, "src", folder);

    let entries;
    try {
      entries = await fs.readdir(dirPath, { withFileTypes: true });
    } catch (err) {
      if (err.code === "ENOENT") return [];
      throw err;
    }

    return entries
      .filter((e) => e.isFile() && e.name.endsWith(".lua"))
      .map((e) => e.name.slice(0, -4)) // strip ".lua"
      .sort();
  }

  // ── getProjectStructure ──────────────────────────────────────────────

  /**
   * Walk the src/ tree and return its structure as a JSON object.
   * Directories become objects, files become the string "[filename]".
   *
   * @returns {Promise<object>}
   */
  async getProjectStructure() {
    this._assertReady();
    const srcPath = path.join(this.projectPath, "src");
    return await this._walkDir(srcPath);
  }

  /** Recursive directory walker. */
  async _walkDir(dirPath) {
    const result = {};
    let entries;
    try {
      entries = await fs.readdir(dirPath, { withFileTypes: true });
    } catch {
      // Directory doesn't exist (yet) — return empty
      return {};
    }

    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        result[entry.name] = await this._walkDir(fullPath);
      } else if (entry.isFile()) {
        result[entry.name] = `[${entry.name}]`;
      }
    }
    return result;
  }
}

// ─── Exports ────────────────────────────────────────────────────────────────

module.exports = { RobloxProject };
