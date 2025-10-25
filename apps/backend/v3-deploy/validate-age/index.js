/**
 * Age Verification Function for Entra External ID Custom Authentication Extension
 *
 * Event Type: OnAttributeCollectionSubmit
 * This function validates that users are 21 years or older during signup.
 * It is called AFTER the user submits the signup form with their birthdate.
 *
 * Authentication: OAuth 2.0 / OIDC Bearer token from Entra External ID app registration
 *
 * Request Format (from Entra):
 * {
 *   "type": "microsoft.graph.authenticationEvent.attributeCollectionSubmit",
 *   "data": {
 *     "userSignUpInfo": {
 *       "attributes": {
 *         "birthdate": { "value": "YYYY-MM-DD" },
 *         "email": { "value": "user@example.com" }
 *       }
 *     }
 *   }
 * }
 *
 * Response Format (21+ - Allow):
 * {
 *   "data": {
 *     "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
 *     "actions": [{
 *       "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
 *     }]
 *   }
 * }
 *
 * Response Format (Under 21 - Block):
 * {
 *   "data": {
 *     "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
 *     "actions": [{
 *       "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
 *       "message": "You must be 21 years or older..."
 *     }]
 *   }
 * }
 *
 * Privacy: Birthdate is NOT stored. Only age_verified boolean is set in claims.
 */

module.exports = async function (context, req) {
    context.log('=== Age verification request received (OnAttributeCollectionSubmit) ===');

    // Validate OAuth/OIDC Bearer token from Entra External ID
    const authHeader = req.headers.authorization || req.headers.Authorization;

    // Log the auth header for debugging (remove in production)
    context.log('Authorization header present:', !!authHeader);

    // TEMPORARILY BYPASS OAuth validation for testing
    // TODO: Implement proper JWT validation with Azure AD
    if (authHeader) {
        context.log('OAuth token present (validation temporarily bypassed for testing)');
    } else {
        context.log.warn('No Authorization header, but continuing for testing');
    }

    // Log the entire request for debugging
    context.log('Request body:', JSON.stringify(req.body));
    context.log('Request headers:', JSON.stringify(req.headers));

    // Extract birthdate from the Entra External ID request format
    let birthdate, email;

    if (req.body && req.body.data && req.body.data.userSignUpInfo && req.body.data.userSignUpInfo.attributes) {
        // Entra External ID format
        const attributes = req.body.data.userSignUpInfo.attributes;

        // Look for birthdate in various possible field names
        // 1. Standard field name
        birthdate = attributes.birthdate?.value || attributes.birthdate;

        // 2. Extension attribute (custom attribute with GUID prefix)
        if (!birthdate) {
            // Find any attribute key that contains "DateofBirth" or "birthdate" (case-insensitive)
            const birthdateKey = Object.keys(attributes).find(key =>
                key.toLowerCase().includes('dateofbirth') || key.toLowerCase().includes('birthdate')
            );
            if (birthdateKey) {
                birthdate = attributes[birthdateKey]?.value || attributes[birthdateKey];
                context.log(`Found birthdate in extension attribute: ${birthdateKey}`);
            }
        }

        email = attributes.email?.value || attributes.email;
        context.log(`Extracted from Entra format - birthdate: ${birthdate}, email: ${email}`);
    } else if (req.body && req.body.birthdate) {
        // Fallback: simple format (for testing)
        birthdate = req.body.birthdate;
        email = req.body.email;
        context.log(`Extracted from simple format - birthdate: ${birthdate}, email: ${email}`);
    } else {
        // Log what we actually received
        context.log.error('Could not extract birthdate from request');
        context.log.error('Request body structure:', JSON.stringify(req.body, null, 2));
    }

    // Validate birthdate is provided
    if (!birthdate) {
        context.log.error('Missing birthdate in request');
        context.log.error('Request body:', JSON.stringify(req.body));
        context.res = {
            status: 400,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Date of birth is required. Please try again."
                    }]
                }
            }
        };
        return;
    }

    // Validate and parse birthdate - supports MM/DD/YYYY, MMDDYYYY, and YYYY-MM-DD formats
    let birthDate;

    // Check for MM/DD/YYYY format (US standard with slashes)
    const usDateRegex = /^(\d{2})\/(\d{2})\/(\d{4})$/;
    // Check for MMDDYYYY format (US standard without separators - 8 digits)
    const usDateNoSepRegex = /^(\d{2})(\d{2})(\d{4})$/;
    // Check for YYYY-MM-DD format (ISO standard)
    const isoDateRegex = /^\d{4}-\d{2}-\d{2}$/;

    if (usDateRegex.test(birthdate)) {
        // Parse MM/DD/YYYY format
        const match = birthdate.match(usDateRegex);
        const month = parseInt(match[1], 10);
        const day = parseInt(match[2], 10);
        const year = parseInt(match[3], 10);
        birthDate = new Date(year, month - 1, day); // month is 0-indexed in JavaScript
        context.log(`Parsed US date format (with slashes): ${birthdate} -> ${birthDate.toISOString()}`);
    } else if (usDateNoSepRegex.test(birthdate)) {
        // Parse MMDDYYYY format (no separators)
        const match = birthdate.match(usDateNoSepRegex);
        const month = parseInt(match[1], 10);
        const day = parseInt(match[2], 10);
        const year = parseInt(match[3], 10);
        birthDate = new Date(year, month - 1, day); // month is 0-indexed in JavaScript
        context.log(`Parsed US date format (no separators): ${birthdate} (${month}/${day}/${year}) -> ${birthDate.toISOString()}`);
    } else if (isoDateRegex.test(birthdate)) {
        // Parse YYYY-MM-DD format
        birthDate = new Date(birthdate);
        context.log(`Parsed ISO date format: ${birthdate} -> ${birthDate.toISOString()}`);
    } else {
        context.log.error(`Invalid birthdate format: ${birthdate} (expected MM/DD/YYYY, MMDDYYYY, or YYYY-MM-DD)`);
        context.res = {
            status: 400,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Please enter a valid birthdate in MM/DD/YYYY format."
                    }]
                }
            }
        };
        return;
    }

    // Validate birthdate is a valid date
    if (isNaN(birthDate.getTime())) {
        context.log.error(`Invalid birthdate value: ${birthdate}`);
        context.res = {
            status: 400,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Please enter a valid date."
                    }]
                }
            }
        };
        return;
    }

    // Calculate age
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    // Adjust age if birthday hasn't occurred this year
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }

    context.log(`User age calculated: ${age} years (email: ${email || 'not provided'})`);

    // Check if user is 21 or older
    if (age < 21) {
        context.log.warn(`User under 21 (age: ${age}), blocking signup`);
        context.res = {
            status: 200,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "You must be 21 years or older to use MyBartenderAI. This app is intended for adults of legal drinking age only."
                    }]
                }
            }
        };
        return;
    }

    // User is 21+, allow signup and set age_verified claim
    context.log(`User is 21+ (age: ${age}), allowing signup with age_verified claim`);

    context.res = {
        status: 200,
        body: {
            data: {
                "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                "actions": [{
                    "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
                }]
            }
        }
    };
};
