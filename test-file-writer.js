#!/usr/bin/env node
/**
 * Test suite for RobloxProject (file writer).
 *
 * Creates a temporary copy of the reference project, runs all tests,
 * then cleans up.  Exits with code 0 on success, 1 on failure.
 */

const fs = require("fs/promises");
const path = require("path");
const { execSync } = require("child_process");
const { RobloxProject } = require("./roblox-project");

// ── Config ──────────────────────────────────────────────────────────────────

const ORIGINAL_PROJECT = "/opt/henderson/roblox-reference";
const TEST_COPY = "/tmp/roblox-reference-test-copy";

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    passed++;
    console.log(`  ✅ ${message}`);
  } else {
    failed++;
    console.error(`  ❌ ${message}`);
  }
}

async function assertRejects(fn, expectedMessage, label) {
  try {
    await fn();
    failed++;
    console.error(`  ❌ ${label} — expected rejection but resolved`);
  } catch (err) {
    if (expectedMessage && !err.message.includes(expectedMessage)) {
      failed++;
      console.error(
        `  ❌ ${label} — wrong error message.\n` +
          `     Expected containing: "${expectedMessage}"\n` +
          `     Got: "${err.message}"`
      );
    } else {
      passed++;
      console.log(`  ✅ ${label}`);
    }
  }
}

async function setup() {
  // Clean up any leftover
  await fs.rm(TEST_COPY, { recursive: true, force: true });
  // Copy the full project
  execSync(`cp -a ${ORIGINAL_PROJECT} ${TEST_COPY}`, { stdio: "ignore" });
}

async function teardown() {
  await fs.rm(TEST_COPY, { recursive: true, force: true });
}

// ── Tests ───────────────────────────────────────────────────────────────────

async function testWriteScript(project) {
  console.log("\n📝 Test: writeScript");

  const source = `--!strict\n\nlocal hello = "world"\nprint(hello)\n`;
  const writtenPath = await project.writeScript("Greet.server", source, "ServerScriptService");

  // Verify file exists at correct path
  const expectedPath = path.join(TEST_COPY, "src", "ServerScriptService", "Greet.server.lua");
  assert(writtenPath === expectedPath, `File written to correct path: ${expectedPath}`);

  // Verify content (allow for StyLua formatting changes)
  const content = await fs.readFile(expectedPath, "utf-8");
  assert(content.length > 0, "File is non-empty");
  assert(content.includes("hello"), "File contains expected variable name 'hello'");
  assert(content.includes("print"), "File contains expected function call 'print'");
}

async function testWriteModelJson(project) {
  console.log("\n📝 Test: writeModelJson");

  const modelData = {
    ClassName: "ModuleScript",
    Name: "HelloWorld",
    Source: "return { greeting = 'Hello, world!' }",
  };
  const writtenPath = await project.writeModelJson("HelloMod", modelData, "ReplicatedStorage");

  const expectedPath = path.join(TEST_COPY, "src", "ReplicatedStorage", "HelloMod.model.json");
  assert(writtenPath === expectedPath, `Model JSON written to correct path: ${expectedPath}`);

  // Verify content
  const raw = await fs.readFile(expectedPath, "utf-8");
  const parsed = JSON.parse(raw);
  assert(parsed.ClassName === "ModuleScript", "Model JSON has correct ClassName");
  assert(parsed.Source.includes("Hello, world!"), "Model JSON has correct Source");
}

async function testGetScriptContent(project) {
  console.log("\n📝 Test: getScriptContent");

  const source = `--!strict\n\nlocal x = 42\n`;
  await project.writeScript("Answer", source, "ServerScriptService");

  const readBack = await project.getScriptContent("Answer", "ServerScriptService");
  assert(readBack.includes("x = 42"), "Read back script contains expected content");
}

async function testPathValidation(project) {
  console.log("\n📝 Test: path traversal prevention");

  // Try writeScript with path-traversal name
  await assertRejects(
    () => project.writeScript("../../etc/passwd", "x", "ServerScriptService"),
    "Path traversal",
    "writeScript rejects '../' in name"
  );

  // Try writeScript with path-traversal folder
  await assertRejects(
    () => project.writeScript("SafeName", "x", "../../etc"),
    "Path traversal",
    "writeScript rejects '../' in folder"
  );

  // Try with absolute path components
  await assertRejects(
    () => project.writeScript("/etc/passwd", "x", "ServerScriptService"),
    "Absolute path",
    "writeScript rejects absolute path in name"
  );

  // Try deleteScript with traversal
  await assertRejects(
    () => project.deleteScript("../../etc/passwd", "ServerScriptService"),
    "Path traversal",
    "deleteScript rejects '../' in name"
  );

  // Try writeModelJson with traversal
  await assertRejects(
    () => project.writeModelJson("../bad", {}, "ServerScriptService"),
    "Path traversal",
    "writeModelJson rejects '../' in name"
  );

  // Try listScripts with traversal
  await assertRejects(
    () => project.listScripts("../../etc"),
    "Path traversal",
    "listScripts rejects '../' in folder"
  );

  // Non-existent folder should return empty, not throw
  const emptyList = await project.listScripts("NonExistentFolder");
  assert(Array.isArray(emptyList) && emptyList.length === 0, "listScripts on non-existent folder returns []");
}

async function testConcurrentWrites(project) {
  console.log("\n📝 Test: concurrent writes");

  const source1 = `-- script 1\nlocal a = 1\n`;
  const source2 = `-- script 2\nlocal b = 2\n`;

  const results = await Promise.allSettled([
    project.writeScript("ConcurrentA", source1, "ReplicatedStorage"),
    project.writeScript("ConcurrentB", source2, "ReplicatedStorage"),
  ]);

  assert(results[0].status === "fulfilled", "Concurrent write A succeeded");
  assert(results[1].status === "fulfilled", "Concurrent write B succeeded");

  // Verify both files exist and have correct content
  const contentA = await project.getScriptContent("ConcurrentA", "ReplicatedStorage");
  const contentB = await project.getScriptContent("ConcurrentB", "ReplicatedStorage");

  assert(contentA.includes("local a = 1"), "Concurrent write A has correct content");
  assert(contentB.includes("local b = 2"), "Concurrent write B has correct content");
}

async function testDeleteScript(project) {
  console.log("\n📝 Test: deleteScript");

  const source = `-- to be deleted\nprint("goodbye")\n`;
  await project.writeScript("DeleteMe", source, "ServerScriptService");

  const filePath = path.join(TEST_COPY, "src", "ServerScriptService", "DeleteMe.lua");
  let exists;
  try { await fs.stat(filePath); exists = true; } catch { exists = false; }
  assert(exists, "File exists before deletion");

  const deleted = await project.deleteScript("DeleteMe", "ServerScriptService");
  assert(deleted === true, "deleteScript returns true on success");

  try { await fs.stat(filePath); exists = true; } catch { exists = false; }
  assert(!exists, "File is gone after deletion");

  // Delete non-existent file
  const noFile = await project.deleteScript("NeverExisted", "ServerScriptService");
  assert(noFile === false, "deleteScript returns false for missing file");
}

async function testListScripts(project) {
  console.log("\n📝 Test: listScripts");

  // Write a few scripts
  await project.writeScript("Alpha", "-- a\n", "ReplicatedStorage");
  await project.writeScript("Beta", "-- b\n", "ReplicatedStorage");
  await project.writeScript("Gamma", "-- c\n", "ReplicatedStorage");

  const list = await project.listScripts("ReplicatedStorage");
  assert(list.includes("Alpha"), "listScripts includes 'Alpha'");
  assert(list.includes("Beta"), "listScripts includes 'Beta'");
  assert(list.includes("Gamma"), "listScripts includes 'Gamma'");
  assert(list.length >= 3, "listScripts returns at least 3 items");
  // Check sorted
  assert(list[0] <= list[1], "listScripts returns sorted results");
}

async function testGetProjectStructure(project) {
  console.log("\n📝 Test: getProjectStructure");

  const structure = await project.getProjectStructure();

  assert(typeof structure === "object" && !Array.isArray(structure),
    "getProjectStructure returns an object");

  // Should contain known service folders
  const hasServerSS = "ServerScriptService" in structure;
  const hasReplicated = "ReplicatedStorage" in structure;
  assert(hasServerSS, "Structure includes ServerScriptService");
  assert(hasReplicated, "Structure includes ReplicatedStorage");

  // The Init.server.lua should be visible
  if (structure.ServerScriptService) {
    const hasInit = "Init.server.lua" in structure.ServerScriptService;
    assert(hasInit, "Structure includes Init.server.lua in ServerScriptService");
  }

  // Newly written files should appear
  const hasInitStr = JSON.stringify(structure);
  assert(hasInitStr.includes("Greet.server.lua"), "Structure includes Greet.server.lua");
  assert(hasInitStr.includes("HelloMod.model.json"), "Structure includes HelloMod.model.json");
}

async function testRojoBuild(project) {
  console.log("\n📝 Test: rojo build (project integrity)");

  // Build the project to a temp file
  const buildPath = "/tmp/roblox-test-build.rbxlx";
  try {
    execSync(
      `rojo build ${TEST_COPY} --output ${buildPath}`,
      { stdio: "pipe", timeout: 30_000 }
    );
    // Check build output exists and is non-empty
    const stat = await fs.stat(buildPath);
    assert(stat.size > 0, `rojo build produced a ${(stat.size / 1024).toFixed(0)} KB file`);
    await fs.unlink(buildPath).catch(() => {});
  } catch (err) {
    // If rojo build fails, provide diagnostic info
    failed++;
    console.error(`  ❌ rojo build failed: ${err.stderr?.toString() || err.message}`);
    // Still show the project structure for debugging
    const struct = await project.getProjectStructure();
    console.error(`     Project structure: ${JSON.stringify(struct, null, 2)}`);
  }
}

// ── Main runner ─────────────────────────────────────────────────────────────

async function main() {
  console.log("=".repeat(60));
  console.log("🧪 RobloxProject — File Writer Test Suite");
  console.log("=".repeat(60));

  await setup();

  const project = new RobloxProject(TEST_COPY);
  await project.init();

  // Run tests in sequence
  await testWriteScript(project);
  await testWriteModelJson(project);
  await testGetScriptContent(project);
  await testPathValidation(project);
  await testConcurrentWrites(project);
  await testDeleteScript(project);
  await testListScripts(project);
  await testGetProjectStructure(project);
  await testRojoBuild(project);

  // Cleanup
  await teardown();

  // Summary
  console.log("\n" + "=".repeat(60));
  console.log(`📊 Results: ${passed} passed, ${failed} failed`);
  console.log("=".repeat(60));

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  teardown().catch(() => {});
  process.exit(1);
});
