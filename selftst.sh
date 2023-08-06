#!/bin/sh
rm ./resSlf/*
echo "Started">./resSlf/res
for F in ./linux/*.dcu; do
  ./dcu32int -U/home/alex/kylix/lib $F "./resSlf/*" |tee -a ./resSlf/res
done
echo "Ended" >>./resSlf/res

