package terraform_test

import (
    "os"
    "path/filepath"
    "strings"
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/require"
)

func TestInfrastructureModules(t *testing.T) {
    if os.Getenv("N8N_TERRATEST_ENABLED") != "1" {
        t.Skip("N8N_TERRATEST_ENABLED not set; skipping integration test")
    }

    hostedZoneName := requireEnv(t, "N8N_TEST_HOSTED_ZONE_NAME")
    domainName := requireEnv(t, "N8N_TEST_DOMAIN")
    sshKey := requireEnv(t, "N8N_TEST_SSH_KEY_NAME")
    acmeEmail := requireEnv(t, "N8N_TEST_LETSENCRYPT_EMAIL")
    profile := getEnvDefault("N8N_TEST_AWS_PROFILE", "sandbox")
    region := getEnvDefault("N8N_TEST_AWS_REGION", "us-east-1")
    allowedSSH := parseCIDRS(getEnvDefault("N8N_TEST_ALLOWED_SSH_CIDR", "0.0.0.0/0"))

    terraformDir := filepath.Clean(filepath.Join("..", "..", "infra", "terraform"))

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: terraformDir,
        Vars: map[string]interface{}{
            "hosted_zone_name": hostedZoneName,
            "domain_name":     domainName,
            "ssh_key_name":    sshKey,
            "letsencrypt_email": acmeEmail,
            "aws_profile":     profile,
            "aws_region":      region,
            "allowed_ssh_cidr": allowedSSH,
        },
        EnvVars: map[string]string{
            "AWS_PROFILE": profile,
            "AWS_REGION":  region,
        },
    })

    terraform.InitAndApply(t, terraformOptions)
    t.Cleanup(func() {
        terraform.Destroy(t, terraformOptions)
    })

    t.Run("network", func(t *testing.T) {
        sgID := terraform.Output(t, terraformOptions, "security_group_id")
        require.NotEmpty(t, sgID)
    })

    t.Run("compute", func(t *testing.T) {
        publicIP := terraform.Output(t, terraformOptions, "instance_public_ip")
        require.NotEmpty(t, publicIP)
    })

    t.Run("dns", func(t *testing.T) {
        fqdn := terraform.Output(t, terraformOptions, "n8n_url")
        require.Contains(t, fqdn, domainName)
    })
}

func requireEnv(t *testing.T, key string) string {
    t.Helper()
    val := os.Getenv(key)
    if val == "" {
        t.Fatalf("missing required env var %s for Terratest", key)
    }
    return val
}

func getEnvDefault(key, fallback string) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return fallback
}

func parseCIDRS(raw string) []string {
    parts := strings.Split(raw, ",")
    cidrs := make([]string, 0, len(parts))
    for _, part := range parts {
        trimmed := strings.TrimSpace(part)
        if trimmed != "" {
            cidrs = append(cidrs, trimmed)
        }
    }
    if len(cidrs) == 0 {
        cidrs = []string{"0.0.0.0/0"}
    }
    return cidrs
}
