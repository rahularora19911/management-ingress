/*
 Licensed Materials - Property of IBM
 (c) Copyright IBM Corporation 2018, 2019. All Rights Reserved.
 Note to U.S. Government Users Restricted Rights:
 Use, duplication or disclosure restricted by GSA ADP Schedule
 Contract with IBM Corp.
 Copyright (c) 2020 Red Hat, Inc.

Copyright 2015 The Kubernetes Authors.

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

package parser

import (
	"fmt"
	"strconv"

	extensions "k8s.io/api/extensions/v1beta1"

	"github.com/open-cluster-management/management-ingress/pkg/ingress/errors"
)

var (
	// AnnotationsPrefix defines the common prefix used in the nginx ingress controller
	AnnotationsPrefix = "ingress.open-cluster-management.io"
)

// IngressAnnotation has a method to parse annotations located in Ingress
type IngressAnnotation interface {
	Parse(ing *extensions.Ingress) (interface{}, error)
}

type ingAnnotations map[string]string

func (a ingAnnotations) parseBool(name string) (bool, error) {
	val, ok := a[name]
	if ok {
		b, err := strconv.ParseBool(val)
		if err != nil {
			return false, errors.NewInvalidAnnotationContent(name, val)
		}
		return b, nil
	}
	return false, errors.ErrMissingAnnotations
}

func (a ingAnnotations) parseString(name string) (string, error) {
	val, ok := a[name]
	if ok {
		return val, nil
	}
	return "", errors.ErrMissingAnnotations
}

func (a ingAnnotations) parseInt(name string) (int, error) {
	val, ok := a[name]
	if ok {
		i, err := strconv.Atoi(val)
		if err != nil {
			return 0, errors.NewInvalidAnnotationContent(name, val)
		}
		return i, nil
	}
	return 0, errors.ErrMissingAnnotations
}

func checkAnnotation(name string, ing *extensions.Ingress) error {
	if ing == nil || len(ing.GetAnnotations()) == 0 {
		return errors.ErrMissingAnnotations
	}
	if name == "" {
		return errors.ErrInvalidAnnotationName
	}

	return nil
}

// GetBoolAnnotation extracts a boolean from an Ingress annotation
func GetBoolAnnotation(name string, ing *extensions.Ingress) (bool, error) {
	v := GetAnnotationWithPrefix(name)
	err := checkAnnotation(v, ing)
	if err != nil {
		return false, err
	}

	b, err := ingAnnotations(ing.GetAnnotations()).parseBool(v)

	if err != nil {
		v = GetAnnotationWithDeprecatedPrefix(name)
		err = checkAnnotation(v, ing)
		if err != nil {
			return false, err
		}
		return ingAnnotations(ing.GetAnnotations()).parseBool(v)
	}
	return b, nil
}

// GetStringAnnotation extracts a string from an Ingress annotation
func GetStringAnnotation(name string, ing *extensions.Ingress) (string, error) {
	v := GetAnnotationWithPrefix(name)
	err := checkAnnotation(v, ing)
	if err != nil {
		return "", err
	}

	val, err := ingAnnotations(ing.GetAnnotations()).parseString(v)

	if err != nil {
		v = GetAnnotationWithDeprecatedPrefix(name)
		err = checkAnnotation(v, ing)
		if err != nil {
			return "", err
		}
		return ingAnnotations(ing.GetAnnotations()).parseString(v)
	}

	return val, nil
	
}

// GetIntAnnotation extracts an int from an Ingress annotation
func GetIntAnnotation(name string, ing *extensions.Ingress) (int, error) {
	v := GetAnnotationWithPrefix(name)
	err := checkAnnotation(v, ing)
	if err != nil {
		return 0, err
	}

	idx, err := ingAnnotations(ing.GetAnnotations()).parseInt(v)
	
	if err != nil {
		v = GetAnnotationWithDeprecatedPrefix(name)
		err = checkAnnotation(v, ing)
		if err != nil {
			return 0, err
		}
		return ingAnnotations(ing.GetAnnotations()).parseInt(v)
	}
	return idx, nil
}

// GetAnnotationWithPrefix returns the prefix of ingress annotations
func GetAnnotationWithPrefix(suffix string) string {
	return fmt.Sprintf("%v/%v", AnnotationsPrefix, suffix)
}

// GetAnnotationWithDeprecatedPrefix returns the prefix of ingress annotations
func GetAnnotationWithDeprecatedPrefix(suffix string) string {
	return fmt.Sprintf("%v/%v", "icp.management.ibm.com", suffix)
}