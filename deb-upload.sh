#!/bin/env bash

# Check if all required environment variables are set
if [ -z "$USER" ]; then
  echo "Error: The environment variable USER is not set."
  exit 1
fi

if [ -z "$TOKEN" ]; then
  echo "Error: The environment variable TOKEN is not set."
  exit 1
fi

if [ -z "$FORGEJO_SERVER_URL" ]; then
  echo "Error: The environment variable FORGEJO_SERVER_URL is not set."
  exit 1
fi

if [ -z "$DIST" ]; then
  echo "Error: The environment variable DIST is not set."
  exit 1
fi

if [ -z "$COMPONENT" ]; then
  echo "Error: The environment variable COMPONENT is not set."
  exit 1
fi

if [ -z "$OVERWRITE" ]; then
  echo "Error: The environment variable OVERWRITE is not set."
  exit 1
fi

REPO_URL="$FORGEJO_SERVER_URL/api/packages/$USER/debian/pool/$DIST/$COMPONENT"

# Function to check if the version already exists in the repository
check_version_exists() {
  local package_name=$1
  local package_version=$2
  local arch=$3
  local check_url="$REPO_URL/${package_name}_${package_version}_${arch}.deb"
  
  echo "Checking if the version already exists: $check_url"
  local http_status
  http_status=$(curl --user "$USER":"$TOKEN" -s -o /dev/null -w "%{http_code}" "$check_url")
  
  echo "HTTP Status: $http_status"
  if [ "$http_status" -eq 200 ]; then
    return 0  # Version exists
  else
    return 1  # Version does not exist
  fi
}

# Function to delete the existing version
delete_version() {
  local package_name=$1
  local package_version=$2
  local arch=$3
  local delete_url="$REPO_URL/$package_name/$package_version/$arch"
  
  echo "Deleting existing version: $delete_url"
  curl --user "$USER":"$TOKEN" -X DELETE "$delete_url"
}

# Function to upload the new version
upload_package() {
  local deb_file=$1
  local upload_url="$REPO_URL/upload"
  
  echo "Uploading new version: $upload_url"
  curl --user "$USER":"$TOKEN" --upload-file "$deb_file" "$upload_url"
  echo "Upload of $deb_file completed."
}

# Check if at least one .deb file is provided as an argument
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <deb-file1> <deb-file2> ..."
  exit 1
fi

# Process each provided .deb file
for DEB_FILE in "$@"; do
  echo "Processing file: $DEB_FILE"

  # Extract package name and version from the filename
  PACKAGE_NAME=$(echo "$DEB_FILE" | cut -d'_' -f1)
  PACKAGE_VERSION=$(echo "$DEB_FILE" | cut -d'_' -f2)
  ARCH=$(echo "$DEB_FILE" | cut -d'_' -f3 | cut -d'-' -f1)

  echo "Package name: $PACKAGE_NAME"
  echo "Package version: $PACKAGE_VERSION"
  echo "Architecture: $ARCH"

  # Check if the version already exists in the repository
  if check_version_exists "$PACKAGE_NAME" "$PACKAGE_VERSION" "$ARCH"; then
    if [ "$OVERWRITE" = true ]; then
      delete_version "$PACKAGE_NAME" "$PACKAGE_VERSION" "$ARCH"
      upload_package "$DEB_FILE"
    else
      echo "Version exists. Overwrite is disabled. Skipping file: $DEB_FILE"
    fi
  else
    echo "Version does not exist. No deletion required."
    upload_package "$DEB_FILE"
  fi

  echo "----------------------------------------"
done
