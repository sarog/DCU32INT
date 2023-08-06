#!/bin/sh
rm ./resK3/*
echo "Started">./resK3/res
for F in /usr/local/kylix3/lib/*.dcu; do
  ./dcu32int -U/usr/local/kylix3/lib $F "./resK3/*" |tee -a ./resK3/res
done
echo "Ended" >>./resK3/res

