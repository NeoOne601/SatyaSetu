#!/bin/bash

# Define the project file
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

echo "Sanitizing $PROJECT_FILE..."

# 1. Remove manual FRAMEWORK_SEARCH_PATHS overrides
# This forces Xcode to use the values provided by CocoaPods
sed -i '' '/FRAMEWORK_SEARCH_PATHS =/d' "$PROJECT_FILE"

# 2. Remove manual LIBRARY_SEARCH_PATHS overrides
sed -i '' '/LIBRARY_SEARCH_PATHS =/d' "$PROJECT_FILE"

# 3. Remove EXCLUDED_ARCHS overrides (Let config handle it)
sed -i '' '/EXCLUDED_ARCHS =/d' "$PROJECT_FILE"

echo "Sanitization complete. Project now inherits from .xcconfig files."
