"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sha256 = void 0;
const crypto_1 = require("crypto");
const sha256 = (value) => (0, crypto_1.createHash)('sha256').update(value).digest('hex');
exports.sha256 = sha256;
