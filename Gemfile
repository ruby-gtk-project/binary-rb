# frozen_string_literal: true

source "https://rubygems.org"

# libadwaita bindings; pulls in gtk4, glib2, cairo and friends.
# Building this gem needs libadwaita-1's development files on PKG_CONFIG_PATH.
gem "adwaita", "~> 4.3"
gem "gem_kit"

# ruby-gnome's extconf.rb files require these at build time, but declare them
# as development dependencies of their own gems — so bundler never fetches
# them and every native extension in the chain fails with a LoadError.
gem "native-package-installer"
gem "pkg-config"

group :development, :test do
  gem "minitest", "~> 5.0"
  gem "rake", "~> 13.0"
  gem "rubocop"
end
