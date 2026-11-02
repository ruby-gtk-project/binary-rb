# frozen_string_literal: true

# Point GLib at the schema compiled into the source tree, and keep every write
# in memory so a test run never touches the real dconf database. Both are read
# lazily on first use, so setting them here — before anything requires the app
# — is early enough.
ROOT = File.expand_path('..', __dir__)

ENV['GSETTINGS_SCHEMA_DIR'] = File.join(ROOT, 'data/schemas')
ENV['GSETTINGS_BACKEND'] = 'memory'

# gtk_test_accessible_* read their answers out of GTK's test accessibility
# backend, and without this the a11y context is the production one, which
# stores nothing a test can query: every accessible assertion comes back false
# whatever the widget actually carries.
ENV['GTK_A11Y'] = 'test'
