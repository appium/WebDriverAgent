#!/bin/bash

pushd $WD
rm -rf Build/Intermediates.noindex
zip -r $ZIP_PKG_NAME Build
popd
mv $WD/$ZIP_PKG_NAME ./
