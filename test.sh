#!/usr/bin/env bash
# Simple test script to verify the repository's slash-command CI integration.
# This is run by the `run-tests` workflow when someone comments `/run-tests`
# on a pull request.

set -euo pipefail

echo "=== Slash-command CI test suite ==="
echo ""

# Test 1: Verify the slash-command-dispatch workflow exists and is well-formed.
echo "Test 1: slash-command-dispatch.yml exists"
if [ ! -f ".github/workflows/slash-command-dispatch.yml" ]; then
  echo "FAIL: .github/workflows/slash-command-dispatch.yml not found"
  exit 1
fi
echo "PASS"

# Test 2: Verify the run-tests workflow exists and is well-formed.
echo "Test 2: run-tests.yml exists"
if [ ! -f ".github/workflows/run-tests.yml" ]; then
  echo "FAIL: .github/workflows/run-tests.yml not found"
  exit 1
fi
echo "PASS"

# Test 3: Verify slash-command-dispatch listens on the correct event.
echo "Test 3: slash-command-dispatch.yml triggers on issue_comment"
if ! grep -q "issue_comment" .github/workflows/slash-command-dispatch.yml; then
  echo "FAIL: issue_comment trigger not found in slash-command-dispatch.yml"
  exit 1
fi
echo "PASS"

# Test 4: Verify run-tests.yml triggers on the correct repository_dispatch type.
echo "Test 4: run-tests.yml triggers on repository_dispatch type slash-run-tests"
if ! grep -q "slash-run-tests" .github/workflows/run-tests.yml; then
  echo "FAIL: slash-run-tests dispatch type not found in run-tests.yml"
  exit 1
fi
echo "PASS"

# Test 5: Verify the dispatch workflow checks collaborator permissions.
echo "Test 5: slash-command-dispatch.yml verifies commenter permissions"
if ! grep -q "getCollaboratorPermissionLevel" .github/workflows/slash-command-dispatch.yml; then
  echo "FAIL: permission check not found in slash-command-dispatch.yml"
  exit 1
fi
echo "PASS"

# Test 6: Verify run-tests.yml creates a check run on the PR commit.
echo "Test 6: run-tests.yml creates a GitHub Check Run"
if ! grep -q "checks.create" .github/workflows/run-tests.yml; then
  echo "FAIL: checks.create not found in run-tests.yml"
  exit 1
fi
echo "PASS"

# Test 7: Verify slash-command-dispatch.yml has contents: write (fix from PR #7).
#         The dispatch workflow calls repos.createDispatchEvent which requires
#         contents: write.  Previously it was contents: read, causing a 403.
echo "Test 7: slash-command-dispatch.yml has 'contents: write' permission"
if ! grep -q "contents: write" .github/workflows/slash-command-dispatch.yml; then
  echo "FAIL: 'contents: write' not found in slash-command-dispatch.yml (was it accidentally reverted to 'contents: read'?)"
  exit 1
fi
echo "PASS"

echo ""
echo "=== All tests passed ==="
