#!/usr/bin/env bash
#
# bootstrap-ec2.sh: set up an Ubuntu EC2 instance as the DevOps workstation.
#
# Installs Docker (engine + buildx + compose plugin), kubectl, Terraform and AWS CLI v2.
# Safe to re-run: any tool that's already installed is skipped.
#
# Usage:
#   ./scripts/bootstrap-ec2.sh
#   KUBECTL_VERSION=v1.32.0 ./scripts/bootstrap-ec2.sh   # pin kubectl to match the EKS version
#
# Can also be pasted into EC2 "User data" so a new instance comes up ready to use.

set -euo pipefail

KUBECTL_VERSION="${KUBECTL_VERSION:-}"   # empty = latest stable
TARGET_USER="${SUDO_USER:-${USER:-ubuntu}}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
skip() { printf '    \033[0;32m✓ %s already installed, skipping\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

if ! grep -qi ubuntu /etc/os-release; then
  echo "This script supports Ubuntu only." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64)  ARCH=amd64;  AWS_ARCH=x86_64 ;;
  aarch64) ARCH=arm64;  AWS_ARCH=aarch64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
# shellcheck disable=SC1091
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

log "Installing base packages"
$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg unzip lsb-release
$SUDO install -m 0755 -d /etc/apt/keyrings

# --- Docker ---------------------------------------------------------------
log "Docker"
if have docker; then
  skip "Docker ($(docker --version))"
else
  $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Let the login user run docker without sudo (takes effect on next login).
if id "$TARGET_USER" >/dev/null 2>&1 && ! id -nG "$TARGET_USER" | grep -qw docker; then
  $SUDO usermod -aG docker "$TARGET_USER"
  echo "    Added $TARGET_USER to the docker group. Log out and back in to use docker without sudo."
fi

# --- kubectl (checksum-verified) ------------------------------------------
log "kubectl"
if have kubectl; then
  skip "kubectl ($(kubectl version --client 2>/dev/null | head -1))"
else
  [[ -z "$KUBECTL_VERSION" ]] && KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  tmp="$(mktemp -d)"
  curl -fsSLo "$tmp/kubectl"        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  curl -fsSLo "$tmp/kubectl.sha256" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"
  (cd "$tmp" && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --quiet)
  $SUDO install -o root -g root -m 0755 "$tmp/kubectl" /usr/local/bin/kubectl
  rm -rf "$tmp"
fi

# --- Terraform ------------------------------------------------------------
log "Terraform"
if have terraform; then
  skip "Terraform ($(terraform version | head -1))"
else
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | $SUDO gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
    | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y terraform
fi

# --- AWS CLI v2 -----------------------------------------------------------
log "AWS CLI"
if have aws; then
  skip "AWS CLI ($(aws --version 2>&1))"
else
  tmp="$(mktemp -d)"
  curl -fsSLo "$tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  $SUDO "$tmp/aws/install"
  rm -rf "$tmp"
fi

# --- Summary --------------------------------------------------------------
log "Installed versions"
echo "  docker:    $(docker --version)"
echo "  compose:   $(docker compose version 2>/dev/null || echo 'n/a')"
echo "  kubectl:   $(kubectl version --client 2>/dev/null | head -1)"
echo "  terraform: $(terraform version | head -1)"
echo "  aws:       $(aws --version 2>&1)"
echo
echo "Next: run 'aws configure' with your IAM user's access key (region us-east-2)."
