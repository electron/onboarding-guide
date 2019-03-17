# Steps pulled from https://electronjs.org/docs/development/build-instructions-gn

# You are free and in fact encouraged to modify and improve these helpers
# as you see fit! these approximate the ones i use, but others on the team
# have slightly different ones and some extra aliases you might also find helpful

##### NAVIGATION #####

# TODO(you!): update to correct path
alias e='<YOUR_PATH_TO_ELECTRON_DIR>'

# restart your sccache server if it's having timeout issues
# TODO(you!): update to correct path
alias ss='<YOUR_PATH_TO_ELECTRON_DIR>/external_binaries/sccache --start-server'

##### BUILDING #####

# set minimum mac sdk against which to compile
# usage: set-sdk 10.12 || set-sdk 10.13 || set-sdk 10.14
alias set-sdk='export FORCE_MAC_SDK_MIN="$1"'

# fresh setup and sync (essentially a bootstrap)
alias eb='setup_fresh'  
setup_fresh() {
  # save original pwd
  run_dir=$(pwd)
  # (TODO(you!)): update to correct path
  cd <YOUR_PATH_TO_SRC>
  # run gclient sync in very verbose mode
  gclient sync -vvv
  # set buildtools path
  export CHROMIUM_BUILDTOOLS_PATH=`pwd`/buildtools
  # set sccache path
  export GN_EXTRA_ARGS="${GN_EXTRA_ARGS} cc_wrapper=\"${PWD}/electron/external_binaries/sccache\""
  # generate ninja files with sccache path set
  gn gen out/Debug --args="import(\"//electron/build/args/debug.gn\") $GN_EXTRA_ARGS"
  # return to original directory
  cd $run_dir
}

# build electron from src
alias ebd='build_e'
build_e() {
  # save original pwd
  run_dir=$(pwd)
  # (TODO(you!)): update to correct path
  cd <YOUR_PATH_TO_SRC>
  # compile and link everything!
  ninja -C out/Debug electron:electron
  # return to original directory
  cd $run_dir
}

# rebuild node headers and run tests in ci mode
alias et='test_setup_run'
test_setup_run() {
  # save original pwd
  run_dir=$(pwd)
  # TODO(you!): update to correct path
  cd <YOUR_PATH_TO_SRC>
  # build electron again just in case
  ebd
  # (re)generate node build headers for the modules to compile against
  ninja -C out/Debug third_party/electron_node:headers
  # cd back to electron directory
  # TODO(you!): update to correct path
  cd <YOUR_PATH_TO_ELECTRON_DIR>
  # run electron tests in ci mode
  npm test -- --ci
  # return to original directory
  cd $run_dir
}

##### RUNNING #####

# run an app with your local version of electron
alias ebrun='build_run'

# TODO(you!): update with your path to the elecron binary
alias erun='<YOUR_PATH_TO_ELECTRON_BINARY>'
build_run() {
  # save original pwd
  run_dir=$(pwd)
  # build electron again to ensure you're running with all your changes
  ebd
  # run the app you passed in as an argument w/ electron binary 
  erun $1
  # return to original directory
  cd $run_dir
}

##### DEBUGGING #####

# set electron binary as debug target and run with lldb
# you can use this to run and test a crash and see a better stack trace!
# https://lldb.llvm.org/lldb-gdb.html
# TODO(you!): update with your path to the elecron binary
alias debug='lldb <YOUR_PATH_TO_ELECTRON_BINARY>'
