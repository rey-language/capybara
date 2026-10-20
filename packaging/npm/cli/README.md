# @capybara/cli

This package provides the capy command for the Rey language. Install it globally:

~~~sh
npm install --global @capybara/cli
capy --version
~~~

The CLI package selects the matching optional platform package for macOS arm64,
macOS x64, Linux x64, or Linux arm64. The platform package includes the capy
binary and pinned Rey toolchain. Installation does not download binaries through
a postinstall hook.
