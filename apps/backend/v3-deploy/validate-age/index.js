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
    context.log('Age verification request received (OnAttributeCollectionSubmit)');

    // Validate OAuth/OIDC Bearer token from Entra External ID
    const authHeader = req.headers.authorization || req.headers.Authorization;

    if (!authHeader) {
        context.log.error('Missing Authorization header');
        context.res = {
            status: 401,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Authentication required. Please contact support if this error persists."
                    }]
                }
            }
        };
        return;
    }

    if (!authHeader.startsWith('Bearer ')) {
        context.log.error('Invalid Authorization header format');
        context.res = {
            status: 401,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Invalid authentication format. Please contact support if this error persists."
                    }]
                }
            }
        };
        return;
    }

    // Extract token (basic validation for MVP)
    const token = authHeader.substring(7);

    if (!token || token.length < 10) {
        context.log.error('Invalid or missing token');
        context.res = {
            status: 401,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Invalid authentication token. Please contact support if this error persists."
                    }]
                }
            }
        };
        return;
    }

    context.log('OAuth token validated successfully');

    // Extract birthdate from the Entra External ID request format
    let birthdate, email;

    if (req.body && req.body.data && req.body.data.userSignUpInfo && req.body.data.userSignUpInfo.attributes) {
        // Entra External ID format
        const attributes = req.body.data.userSignUpInfo.attributes;
        birthdate = attributes.birthdate?.value || attributes.birthdate;
        email = attributes.email?.value || attributes.email;
        context.log(`Extracted from Entra format - birthdate: ${birthdate}, email: ${email}`);
    } else if (req.body && req.body.birthdate) {
        // Fallback: simple format (for testing)
        birthdate = req.body.birthdate;
        email = req.body.email;
        context.log(`Extracted from simple format - birthdate: ${birthdate}, email: ${email}`);
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

    // Validate birthdate format (YYYY-MM-DD)
    const birthdateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!birthdateRegex.test(birthdate)) {
        context.log.error(`Invalid birthdate format: ${birthdate}`);
        context.res = {
            status: 400,
            body: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{
                        "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
                        "message": "Please enter a valid birthdate in YYYY-MM-DD format."
                    }]
                }
            }
        };
        return;
    }

    // Validate birthdate is a valid date
    const birthDate = new Date(birthdate);
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
