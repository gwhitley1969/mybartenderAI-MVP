# Phase 1 Testing & Review Guide

**Purpose**: Verify all Phase 1 infrastructure is correctly configured before starting Phase 2

**Date**: October 23, 2025

---

## 🎯 Testing Overview

### What We Can Test Now
- ✅ APIM configuration and products
- ✅ Database schema and connectivity
- ✅ Subscription keys and rate limiting
- ✅ Policy enforcement
- ✅ PostgreSQL functions and views

### What We Can't Test Yet (Requires Phase 2)
- ❌ Backend Function responses
- ❌ AI recommendations
- ❌ Snapshot generation
- ❌ Full end-to-end API calls

---

## 📋 Test Plan

### Test 1: APIM Configuration ✅
**Objective**: Verify all APIM products and policies are configured

**Steps**:
1. Check products exist
2. Verify API is imported
3. Confirm policies are applied
4. Test subscription keys

### Test 2: Database Schema ✅
**Objective**: Verify PostgreSQL schema is complete

**Steps**:
1. List all tables
2. Verify all functions exist
3. Test quota functions
4. Check views are created

### Test 3: Rate Limiting ✅
**Objective**: Verify tier-based rate limiting works

**Steps**:
1. Test Free tier limits (10 calls/min)
2. Test Premium tier limits (20 calls/min)
3. Verify 429 responses

### Test 4: Security ✅
**Objective**: Verify authentication and authorization

**Steps**:
1. Test without subscription key (should fail)
2. Test with wrong tier key (should enforce limits)
3. Verify Key Vault access

---

## 🧪 Running the Tests

### Test 1: APIM Configuration

**1.1 List Products**
