# frozen_string_literal: true

require 'fiddle'

# Upstream's translations, read from the same compiled .mo catalogues by the
# same C gettext that GTK itself uses.
#
# There is no gettext in the Ruby standard library and none in the ruby-gnome
# bindings, but every string GTK renders already goes through the libc
# implementation — so this binds to that rather than adding a gem and a second,
# differently-behaving catalogue reader. Plural rules, the LANGUAGE search list
# and the encoding conversion all come along for free.
module I18n
  DOMAIN = 'binary'

  # glibc keeps gettext in libc; elsewhere it lives in a separate libintl.
  LIBRARIES = ['libc.so.6', 'libintl.so.8', 'libintl.so', 'libc.so'].freeze

  # LC_ALL. A glibc number — the categories are not exposed anywhere Ruby can
  # read them, and this is the value on the platform the flake pins.
  # ponytail: hard-coded category; read it from the C headers if this ever has
  # to build against a libc that numbers them differently.
  LC_ALL = 6

  # gettext stores a contextual message under "context\u0004message".
  CONTEXT_SEPARATOR = "\u0004"

  module_function

  def library
    @library ||= LIBRARIES.filter_map { |name| open_library(name) }.first
  end

  def open_library(name)
    Fiddle.dlopen(name)
  rescue Fiddle::DLError
    nil
  end

  def function(name, argument_types)
    @functions ||= {}
    @functions[name] ||= Fiddle::Function.new(
      library[name],
      argument_types,
      Fiddle::TYPE_VOIDP,
    )
  end

  # Point the domain at a directory of <lang>/LC_MESSAGES/binary.mo, and set
  # the process locale from the environment — gettext refuses to translate
  # anything while the locale is still the "C" default.
  def bind(directory)
    function('setlocale', [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP]).call(LC_ALL, '')
    function('bindtextdomain', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
      .call(DOMAIN, directory)
    function('bind_textdomain_codeset', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
      .call(DOMAIN, 'UTF-8')
    function('textdomain', [Fiddle::TYPE_VOIDP]).call(DOMAIN)
  end

  def translate(message)
    from_domain(DOMAIN, message)
  end

  # Upstream asks for the base names out of a domain called "Number base",
  # which no catalogue defines, so they come back untranslated. Kept because
  # the alternative is a port that translates a string upstream does not.
  def from_domain(domain, message)
    function('dgettext', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
      .call(domain, message)
      .to_s
      .force_encoding(Encoding::UTF_8)
  end

  def with_context(context, message)
    from_domain(DOMAIN, "#{context}#{CONTEXT_SEPARATOR}#{message}").then do |translated|
      if translated.include?(CONTEXT_SEPARATOR)
        message
      else
        translated
      end
    end
  end

  # The catalogues carry Python's "%(name)d" placeholders, so the count is
  # substituted here rather than through Ruby's own format syntax.
  def plural(singular, plural, count)
    function(
      'dngettext',
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG],
    )
      .call(
        DOMAIN,
        singular,
        plural,
        count,
      )
      .to_s
      .force_encoding(Encoding::UTF_8)
      .gsub(/%\(\w+\)d/, count.to_s)
  end
end

# Short names, so the call sites read like the ones being ported.
def _(message) = I18n.translate(message)
def d_(domain, message) = I18n.from_domain(domain, message)
def c_(context, message) = I18n.with_context(context, message)
def n_(singular, plural, count) = I18n.plural(singular, plural, count)
