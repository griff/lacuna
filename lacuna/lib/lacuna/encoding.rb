require 'base64'

module Lacuna
  module Encoding
    extend Encoding
    
    def decode_word(text)
      if text =~ /^=\?([^?]+)\?(Q|B)\?([^?]*)\?=$/i
        charset, encoding, text = $1, $2.downcase, $3
        if encoding == 'b'
          Base64.decode(text).force_encoding(charset)
        else
          text = text.gsub(/=[\da-fA-F]{2}/) { quoted_printable_decode($&) }.
                      gsub(/_/, " ")
          text.force_encoding(charset)
        end
      else
        text
      end
    end
    
    def quoted_printable_decode(character)
      result = ""
      result << character[1..-1].to_i(16)
      result
    end
    
    def encode_word(text)
      if text.encoding.ascii_compatible?
        quote_if_necessary(text, text.encoding.name)
      else
        base64(text,text.encoding.name)
      end
    end
    
    def base64(text,charset)
      text = Base64.encode(text)
      "=?#{charset}?B?#{text}?="
    end
    
    # Convert the given text into quoted printable format, with an instruction
    # that the text be eventually interpreted in the given charset.
    def quoted_printable(text, charset)
      text = text.gsub( /[^a-z ]/i ) { quoted_printable_encode($&) }.
                  gsub( / /, "_" )
      "=?#{charset}?Q?#{text}?="
    end

    # Convert the given character to quoted printable format, taking into
    # account multi-byte characters (if executing with $KCODE="u", for instance)
    def quoted_printable_encode(character)
      result = ""
      character.each_byte { |b| result << "=%02X" % b }
      result
    end

    # A quick-and-dirty regexp for determining whether a string contains any
    # characters that need escaping.
    if !defined?(CHARS_NEEDING_QUOTING)
      CHARS_NEEDING_QUOTING = /[\000-\011\013\014\016-\037\177-\377]/
    end

    # Quote the given text if it contains any "illegal" characters
    def quote_if_necessary(text, charset)
      text = text.dup.force_encoding(::Encoding::ASCII_8BIT) if text.respond_to?(:force_encoding)

      (text =~ CHARS_NEEDING_QUOTING) ?
        quoted_printable(text, charset) :
        text
    end
  end
end