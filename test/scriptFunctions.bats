#!/usr/bin/env bats
#shellcheck disable

load 'helpers/bats-support/load'
load 'helpers/bats-file/load'
load 'helpers/bats-assert/load'

sourceDIR="${HOME}/dotfiles/scripting/functions"

[ -d "$sourceDIR" ] || exit 1

while read -r sourcefile; do
  [ -f "$sourcefile" ] && source "$sourcefile"
done < <(find "$sourceDIR" -name "*.bash" -type f -maxdepth 1)

# Fixtures
YAML1="${BATS_TEST_DIRNAME}/fixtures/yaml1.yaml"
YAML1parse="${BATS_TEST_DIRNAME}/fixtures/yaml1.yaml.txt"
YAML2="${BATS_TEST_DIRNAME}/fixtures/yaml2.yaml"
JSON="${BATS_TEST_DIRNAME}/fixtures/json.json"
unencrypted="${BATS_TEST_DIRNAME}/fixtures/test.md"
encrypted="${BATS_TEST_DIRNAME}/fixtures/test.md.enc"

# Set Defaults
force=false;    dryrun=false;    verbose=false;    quiet=false;
printLog=false; debug=false;

setup() {
  # Set arrays
  A=(one two three 1 2 3)
  B=(1 2 3 4 5 6)

  testdir="$(temp_make)"
  curPath="$PWD"

  BATSLIB_FILE_PATH_REM="#${TEST_TEMP_DIR}"
  BATSLIB_FILE_PATH_ADD='<temp>'

  cd "${testdir}"
}

teardown() {
  cd $curPath
  temp_del "${testdir}"
}

@test "_realpath_: true" {
  touch testfile.txt
  run _realpath_ "testfile.txt"
  assert_success
  assert_output --regexp "^/private/var/folders/.*/testfile.txt$"
}

@test "_realpath_: fail" {
  run _realpath_ "testfile.txt"
  assert_failure
}

@test "_findBaseDir_" {
  run _findBaseDir_
  assert_output "${HOME}/dotfiles/scripting/functions"
}

@test "_encryptFile_" {
  PASS=123
  run _encryptFile_ "${unencrypted}" "test-encrypted.md.enc"
  assert_success
  assert_file_exist "test-encrypted.md.enc"
  run cat "test-encrypted.md.enc"
  assert_line --index 0 --partial "Salted__"
  unset PASS
}

@test "_decryptFile_" {
  PASS=123
  run _decryptFile_ "${encrypted}" "test-decrypted.md"
  assert_success
  assert_file_exist "test-decrypted.md"
  run cat "test-decrypted.md"
  assert_success
  assert_output "$( cat "$unencrypted")"
}

@test "_escape_" {
  run _escape_ "Here is some / text to & be - escape'd"
  assert_success
  assert_output "Here\ is\ some\ /\ text\ to\ &\ be\ -\ escape'd"
}

@test "_htmlEncode_" {
  run _htmlEncode_ "Here's some text& to > be h?t/M(l• en™codeç£§¶d"
  assert_success
  assert_output "Here's some text&amp; to &gt; be h?t/M(l&bull; en&trade;code&ccedil;&pound;&sect;&para;d"
}

@test "_htmlDecode_" {
  run _htmlDecode_ "&clubs;Here's some text &amp; to &gt; be h?t/M(l&bull; en&trade;code&ccedil;&pound;&sect;&para;d"
  assert_success
  assert_output "♣Here's some text & to > be h?t/M(l• en™codeç£§¶d"
}

@test "_urlEncode_" {
  run _urlEncode_ "Here's some.text%that&needs_to-be~encoded+a*few@more(characters)"
  assert_success
  assert_output "Here%27s%20some.text%25that%26needs_to-be~encoded%2Ba%2Afew%40more%28characters%29"
}

@test "_urlDecode_" {
  run _urlDecode_ "Here%27s%20some.text%25that%26needs_to-be~encoded%2Ba%2Afew%40more%28characters%29"
  assert_success
  assert_output "Here's some.text%that&needs_to-be~encoded+a*few@more(characters)"
}

@test "_parseYAML_" {
  run _parseYAML_ "$YAML1"
  assert_success
  assert_output "$( cat "$YAML1parse")"
}

@test "_json2yaml_" {
  run _json2yaml_ "$JSON"
  assert_success
  assert_output "$( cat "$YAML2")"
}

@test "_yaml2json_" {
  run _yaml2json_ "$YAML2"
  assert_success
  assert_output "$( cat "$JSON")"
}

@test "_execute_: Debug command" {
  dryrun=true
  run _execute_ "rm testfile.txt"
  assert_success
  assert_output --partial "[ dryrun] rm testfile.txt"
  dryrun=false
}

@test "_execute_: Bad command" {
  touch "testfile.txt"
  run _execute_ "rm nonexistant.txt"
  assert_success
  assert_output --partial "[warning] rm nonexistant.txt"
  assert_file_exist "testfile.txt"
}

@test "_execute_: Good command" {
  touch "testfile.txt"
  run _execute_ "rm testfile.txt"
  assert_success
  assert_output --partial "[success] rm testfile.txt"
  assert_file_not_exist "testfile.txt"
}

@test "_seekConfirmation_: yes" {
  run _seekConfirmation_ 'test' <<<"y"

  assert_success
  assert_output --partial "[  input] test"
}

@test "_seekConfirmation_: no" {
  run _seekConfirmation_ 'test' <<<"n"

  assert_failure
  assert_output --partial "[  input] test"
}

@test "_seekConfirmation_: Force" {
  force=true

  run _seekConfirmation_ "test"
  assert_success
  assert_output --partial "test"

  force=false
}

@test "_seekConfirmation_: Quiet" {
  quiet=true
  run _seekConfirmation_ 'test' <<<"y"

  assert_success
  refute_output --partial "test"

  quiet=false
}

@test "_inArray_: success" {
  run _inArray_ one "${A[@]}"
  assert_success
}

@test "_inArray_: failure" {
  run _inArray_ ten "${A[@]}"
  assert_failure
}

@test "_convertSecs_: Seconds to human readable" {

  run _convertSecs_ "9255"
  assert_success
  assert_output "02:34:15"
}

@test "_httpStatus_: Bad URL" {
  run _httpStatus_ http://natelandaubadurlishere.com 1
  assert_success
  assert_line --index 1 "000 Not responding within 1 seconds"
}

@test "_httpStatus_: redirect" {
  skip "not working yet...."
  run _httpStatus_ https://jigsaw.w3.org/HTTP/300/301.html 3 --status -L
  assert_success
  assert_output --partial "000 Not responding within 3 seconds"
}

@test "_httpStatus_: google.com" {
  run _httpStatus_ google.com
  assert_success
  assert_output --partial "200 Successful:"
}

@test "_httpStatus_: -c" {
  run _httpStatus_ www.google.com 100 -c
  assert_success
  assert_output "200"
}

@test "_httpStatus_: --code" {
  run _httpStatus_ www.google.com 100 --code
  assert_success
  assert_output "200"
}

@test "_httpStatus_: -s" {
  run _httpStatus_ www.google.com 100 -s
  assert_success
  assert_output "200 Successful: OK within 100 seconds"
}

@test "_httpStatus_: --status" {
  run _httpStatus_ www.google.com 100 -s
  assert_success
  assert_output "200 Successful: OK within 100 seconds"
}

@test "_join_: Join array comma" {
  run _join_ , "${B[@]}"
  assert_output "1,2,3,4,5,6"
}

@test "_join_: Join array space" {
  run _join_ " " "${B[@]}"
  assert_output "1 2 3 4 5 6"
}

@test "_join_: Join string complex" {
  run _join_ , a "b c" d
  assert_output "a,b c,d"
}

@test "_join_: join string simple" {
  run _join_ / var usr tmp
  assert_output "var/usr/tmp"
}

@test "_setdiff_: Print elements not common to arrays" {
  run _setdiff_ "${A[*]}" "${B[*]}"
  assert_output "one two three"

  run _setdiff_ "${B[*]}" "${A[*]}"
  assert_output "4 5 6"
}

@test "_ext_: .txt" {
  touch "foo.txt"

  run _ext_ foo.txt
  assert_success
  assert_output ".txt"
}

@test "_ext_: tar.gz" {
  touch "foo.tar.gz"

  run _ext_ foo.tar.gz
  assert_success
  assert_output ".tar.gz"
}

@test "_ext_: -n1" {
  touch "foo.tar.gz"

  run _ext_ -n1 foo.tar.gz
  assert_success
  assert_output ".gz"
}

@test "_ext_: -n2" {
  touch "foo.txt.gz"

  run _ext_ -n2 foo.txt.gz
  assert_success
  assert_output ".txt.gz"
}

@test "_locateSourceFile_: Resolve symlinks" {
  ln -s "$sourceDIR" "testSymlink"

  run _locateSourceFile_ "testSymlink"
  assert_output "$sourceDIR"
}

@test "_uniqueFileName_: Count to 3" {
  touch "test.txt"
  touch "test 2.txt"

  run _uniqueFileName_ "test.txt"
  assert_output --regexp ".*/test 3.txt$"
}

@test "_uniqueFileName_: Don't confuse existing numbers" {
  touch "test 2.txt"

  run _uniqueFileName_ "test 2.txt"
  assert_output --regexp ".*/test 2 2.txt$"
}

@test "_uniqueFileName_: User specified separator" {
  touch "test.txt"

  run _uniqueFileName_ "test.txt" "-"
  assert_output --regexp ".*/test-2.txt$"
}

@test "_readFile_: Reads files line by line" {
cat >testfile.txt <<EOL
line 1
line 2
line 3
EOL

  run _readFile_ "testfile.txt"
  assert_line --index 0 'line 1'
  assert_line --index 2 'line 3'
}

@test "info" {
  run info "testing"
  assert_output --regexp "[0-9]+:[0-9]+:[0-9]+ (AM|PM) \[   info\] testing"
}

@test "error" {
  run error "testing"
  assert_output --regexp "\[  error\] testing"
}

@test "warning" {
  run warning "testing"
  assert_output --regexp "\[warning\] testing"
}

@test "success" {
  run success "testing"
  assert_output --regexp "\[success\] testing"
}

@test "notice" {
  run notice "testing"
  assert_output --regexp "\[ notice\] testing"
}

@test "header" {
  run header "testing"
  assert_output --regexp "\[ header\] == testing =="
}

@test "input" {
  run input "testing"
  assert_output --partial "[  input] testing"
}

@test "debug" {
  run debug "testing"
  assert_output --partial "[  debug] testing"
}

@test "die" {
  run die "testing"
  assert_line --index 0 --partial "[  error] testing Exiting."
  assert_line --index 1 --partial "_safeExit_: command not found"
}

@test "quiet" {
  quiet=true
  run notice "testing"
  assert_success
  refute_output --partial "testing"
  quiet=false
}

@test "verbose" {
  run verbose "testing"
  refute_output --regexp "\[  debug\] testing"

  verbose=true
  run verbose "testing"
  assert_output --regexp "\[  debug\] testing"
  verbose=false
}

@test "logging" {
  printLog=true ; logFile="testlog"
  notice "testing"
  info "testing again"
  success "last test"

  assert_file_exist "${logFile}"

  run cat "${logFile}"
  assert_line --index 0 --partial "[ notice] testing"
  assert_line --index 1 --partial "[   info] testing again"
  assert_line --index 2 --partial "[success] last test"

  printLog=false
}