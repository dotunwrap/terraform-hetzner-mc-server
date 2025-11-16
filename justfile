tflock:
  cd infra && terraform providers lock \
    -platform=windows_amd64 \
    -platform=darwin_amd64 \
    -platform=linux_amd64 \
    -platform=darwin_arm64 \
    -platform=linux_arm64

fmt:
  nix fmt
  cd infra && terraform fmt

apply:
  cd infra && terraform apply

plan:
  cd infra && terraform plan
