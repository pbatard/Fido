#!/bin/bash
# Creates an LZMA compressed Fido.ps1 (including decompressed size) and sign it

PRIVATE_KEY=/d/Secured/Akeo/Rufus/private.pem
PUBLIC_KEY=/d/Secured/Akeo/Rufus/public.pem

# Create or update a signature
sign_file() {
  if [ -f $FILE.sig ]; then
    SIZE=$(stat -c%s $FILE.sig)
    openssl dgst -sha256 -verify $PUBLIC_KEY -signature $FILE.sig $FILE >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
      echo Updating signature for $FILE
      openssl dgst -sha256 -sign $PRIVATE_KEY -passin pass:$PASSWORD -out $FILE.sig $FILE
    fi
  else
    # No signature => create a new one
    echo Creating signature for $FILE
    openssl dgst -sha256 -sign $PRIVATE_KEY -passin pass:$PASSWORD -out $FILE.sig $FILE
  fi
}

# Update the Authenticode signature
cmd.exe /c '"C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool" sign /v /sha1 9ce9a71ccab3b38a74781b975f1c228222cf7d3b /fd SHA256 /tr http://sha256timestamp.ws.symantec.com/sha256/timestamp /td SHA256 Fido.ps1'
read -s -p "Enter pass phrase for `realpath $PRIVATE_KEY`: " PASSWORD
echo
# Confirm that the pass phrase is valid by trying to sign a dummy file
openssl dgst -sha256 -sign $PRIVATE_KEY -passin pass:$PASSWORD $PUBLIC_KEY >/dev/null 2>&1 || { echo Invalid pass phrase; exit 1; }

lzma -kf Fido.ps1
# The 'lzma' utility does not add the uncompressed size, so we must add it manually. And yes, this whole
# gymkhana is what one must actually go through to insert a 64-bit little endian size into a binary file...
printf "00: %016X" `stat -c "%s" Fido.ps1` | xxd -r | xxd -p -c1 | tac | xxd -p -r | dd of=Fido.ps1.lzma seek=5 bs=1 status=none conv=notrunc
find . -maxdepth 1 -name "Fido.ps1.lzma" | while read FILE; do sign_file; done
# Clear the PASSWORD variable just in case
PASSWORD=`head -c 50 /dev/random | base64`
