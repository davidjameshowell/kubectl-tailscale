#!/bin/sh

set -e

version="$1"
config="$2"
command="$3"
tailscale_version="$4"
tailscale_key="$5"

if [ "$version" = "latest" ]; then
  version=$(curl -Ls https://dl.k8s.io/release/stable.txt)
fi

echo "using kubectl@$version"

curl -sLO "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl" -o kubectl
chmod +x kubectl
mv kubectl /usr/local/bin

# Extract the base64 encoded config data and write this to the KUBECONFIG
echo "$config" | base64 -d > /tmp/config
export KUBECONFIG=/tmp/config

# Start Tailscale config
MINOR=$(echo $tailscale_version | awk -F '.' {'print $2'})
if [ $((MINOR % 2)) -eq 0 ]; then
  URL="https://pkgs.tailscale.com/stable/tailscale_${tailscale_version}_amd64.tgz"
else
  URL="https://pkgs.tailscale.com/unstable/tailscale_${tailscale_version}_amd64.tgz"
fi
curl $URL -o tailscale.tgz
tar -C ~ -xzf tailscale.tgz
rm tailscale.tgz
mv "$HOME/tailscale_${tailscale_version}_amd64" ~/.tailscale
chmod +x ~/.tailscale/tailscaled
chmod +x ~/.tailscale/tailscale

# Start Tailscale
~/.tailscale/tailscaled 2>~/.tailscale/tailscaled.log &
sleep 3
~/.tailscale/tailscale up --authkey $tailscale_key --hostname "github-actions-$(cat /etc/hostname)"

sh -c "kubectl $command"
