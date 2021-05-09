# Creating WebDriverAgent bundles using Azure Pipelines

The [bundle](https://dev.azure.com/AppiumCI/Appium%20CI/_build?definitionId=36&_a=summary) pipeline uses macOS agents on Azure and iterates through every installed version of Xcode and then builds WebDriverAgent using ./scripts/build-webdriveragents.js

The bundle pipeline is run every time there is a tag and builds to a folder called `prebuilt-agents` and those agents get uploaded to [GitHub Releases](https://github.com/appium/WebDriverAgent/releases).

The bundle can be run manually as well, but the GitHub release will not be created. This is useful if you wish to test that it bundles correctly but don't wish to publish it.

# Creating WebDriverAgent bundle locally

Building a WebDriverAgent bundle locally is useful if Azure pipelines doesn't build one of the Xcode bundles that we want.

* Run `node ./Scripts/build-webdriveragent.js` 
* This will build a single bundle to `prebuilt-agents`
* The bundle will be built using the Xcode version installed locally
