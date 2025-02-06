#!/bin/bash

# Update version in pubspec.yaml
update_pubspec_version() {
    local version=$1
    sed -i "s/^version: .*/version: $version/" pubspec.yaml
}

# Update version in build.gradle (Android)
update_android_version() {
    local version=$1
    local version_code=$(echo $version | sed 's/[^0-9]//g')
    local version_name=$version
    
    sed -i "s/versionCode .*/versionCode $version_code/" android/app/build.gradle
    sed -i "s/versionName .*/versionName \"$version_name\"/" android/app/build.gradle
}

# Update version in Info.plist (iOS)
update_ios_version() {
    local version=$1
    local build_number=$(echo $version | sed 's/[^0-9]//g')
    
    plutil -replace CFBundleShortVersionString -string "$version" ios/Runner/Info.plist
    plutil -replace CFBundleVersion -string "$build_number" ios/Runner/Info.plist
}

# Main version update function
update_version() {
    local new_version=$1
    
    if [[ ! $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in format X.Y.Z"
        exit 1
    fi
    
    update_pubspec_version "$new_version"
    update_android_version "$new_version"
    update_ios_version "$new_version"
    
    echo "Updated version to $new_version"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 <version>"
        exit 1
    fi
    update_version "$1"
fi