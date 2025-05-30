{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  poetry-core,
  pytestCheckHook,
  pythonOlder,
  requests,
  toml,
  werkzeug,
}:

buildPythonPackage rec {
  pname = "pytest-httpserver";
  version = "1.1.2";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "csernazs";
    repo = "pytest-httpserver";
    tag = version;
    hash = "sha256-41JrZ3ubaJHNzwGDWUSseJ3Z405k21SOpwW7jG5rNxg=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [ werkzeug ];

  nativeCheckInputs = [
    pytestCheckHook
    requests
    toml
  ];

  __darwinAllowLocalNetworking = true;

  disabledTests = [
    "test_wait_raise_assertion_false" # racy
  ];

  pythonImportsCheck = [ "pytest_httpserver" ];

  meta = with lib; {
    description = "HTTP server for pytest to test HTTP clients";
    homepage = "https://www.github.com/csernazs/pytest-httpserver";
    changelog = "https://github.com/csernazs/pytest-httpserver/blob/${version}/CHANGES.rst";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ fab ];
  };
}
