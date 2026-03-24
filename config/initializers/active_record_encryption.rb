# Active Record attribute-level encryption (encrypts :attribute) is not currently
# used in this app. Credentials in the Integration model are encrypted using
# ActiveSupport::MessageEncryptor backed by secret_key_base (see Integration model).
#
# If AR attribute encryption is added in the future, generate keys with:
#   bin/rails db:encryption:init
# and add them to bearclaw-web.env + blink.toml.
