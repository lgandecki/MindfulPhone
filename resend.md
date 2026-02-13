DKIM and SPF Records Required

Type

Host/Name

Value

Priority

TXT

resend._domainkey

p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDmPjljJ8Syr5CawzFgKqPjVO0vFZMW8HpwFZ0WT+OVdyPIMFgVXWHyTGQySZkVqNGRwcNaO9XR023lG++la+gzVwlU0JbLpbX+jSCyyafp7E0fThvvETsJYVE+gN271PSGOr3j6gHUpJv0fgwc7XhEVWGCRL/AeNDRE99H5PmFxQIDAQAB


MX

send

feedback-smtp.us-east-1.amazonses.com

10

TXT

send

v=spf1 include:amazonses.com ~all


DMARC Recommended

Type

Host/Name

Value

TXT

_dmarc

v=DMARC1; p=none;


