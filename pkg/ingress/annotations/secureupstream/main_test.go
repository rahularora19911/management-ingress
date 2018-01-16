/*
Copyright 2016 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package secureupstream

import (
	"fmt"
	"testing"

	api "k8s.io/api/core/v1"
	extensions "k8s.io/api/extensions/v1beta1"
	meta_v1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.ibm.com/IBMPrivateCloud/icp-management-ingress/pkg/ingress/annotations/parser"
	"github.ibm.com/IBMPrivateCloud/icp-management-ingress/pkg/ingress/resolver"
	"k8s.io/apimachinery/pkg/util/intstr"
)

func buildIngress() *extensions.Ingress {
	defaultBackend := extensions.IngressBackend{
		ServiceName: "default-backend",
		ServicePort: intstr.FromInt(80),
	}

	return &extensions.Ingress{
		ObjectMeta: meta_v1.ObjectMeta{
			Name:      "foo",
			Namespace: api.NamespaceDefault,
		},
		Spec: extensions.IngressSpec{
			Backend: &extensions.IngressBackend{
				ServiceName: "default-backend",
				ServicePort: intstr.FromInt(80),
			},
			Rules: []extensions.IngressRule{
				{
					Host: "foo.bar.com",
					IngressRuleValue: extensions.IngressRuleValue{
						HTTP: &extensions.HTTPIngressRuleValue{
							Paths: []extensions.HTTPIngressPath{
								{
									Path:    "/foo",
									Backend: defaultBackend,
								},
							},
						},
					},
				},
			},
		},
	}
}

type mockCfg struct {
	resolver.Mock
	certs map[string]resolver.AuthSSLCert
}

func (cfg mockCfg) GetAuthCertificate(secret string) (*resolver.AuthSSLCert, error) {
	if cert, ok := cfg.certs[secret]; ok {
		return &cert, nil
	}
	return nil, fmt.Errorf("secret not found: %v", secret)
}

func TestAnnotations(t *testing.T) {
	ing := buildIngress()
	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("secure-backends")] = "true"
	data[parser.GetAnnotationWithPrefix("secure-verify-ca-secret")] = "secure-verify-ca"
	ing.SetAnnotations(data)

	_, err := NewParser(mockCfg{
		certs: map[string]resolver.AuthSSLCert{
			"default/secure-verify-ca": {},
		},
	}).Parse(ing)
	if err != nil {
		t.Errorf("Unexpected error on ingress: %v", err)
	}
}

func TestSecretNotFound(t *testing.T) {
	ing := buildIngress()
	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("secure-backends")] = "true"
	data[parser.GetAnnotationWithPrefix("secure-verify-ca-secret")] = "secure-verify-ca"
	ing.SetAnnotations(data)
	_, err := NewParser(mockCfg{}).Parse(ing)
	if err == nil {
		t.Error("Expected secret not found error on ingress")
	}
}

func TestSecretOnNonSecure(t *testing.T) {
	ing := buildIngress()
	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("secure-backends")] = "false"
	data[parser.GetAnnotationWithPrefix("secure-verify-ca-secret")] = "secure-verify-ca"
	ing.SetAnnotations(data)
	_, err := NewParser(mockCfg{
		certs: map[string]resolver.AuthSSLCert{
			"default/secure-verify-ca": {},
		},
	}).Parse(ing)
	if err == nil {
		t.Error("Expected CA secret on non secure backend error on ingress")
	}
}

func TestClientSecretNotFound(t *testing.T) {
	ing := buildIngress()
	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("secure-backends")] = "true"
	data[parser.GetAnnotationWithPrefix("secure-client-ca-secret")] = "secure-client-ca"
	ing.SetAnnotations(data)
	_, err := NewParser(mockCfg{}).Parse(ing)
	if err == nil {
		t.Error("Expected client secret not found error on ingress")
	}
}

func TestClientSecretOnNonSecure(t *testing.T) {
	ing := buildIngress()
	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("secure-backends")] = "false"
	data[parser.GetAnnotationWithPrefix("secure-client-ca-secret")] = "secure-client-ca"
	ing.SetAnnotations(data)
	_, err := NewParser(mockCfg{
		certs: map[string]resolver.AuthSSLCert{
			"default/secure-client-ca": {},
		},
	}).Parse(ing)
	if err == nil {
		t.Error("Expected Client CA secret on non secure backend error on ingress")
	}
}
