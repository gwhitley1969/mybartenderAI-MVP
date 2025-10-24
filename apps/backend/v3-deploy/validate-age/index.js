/**
 * Age Verification Function for Entra External ID API Connector
 *
 * This function validates that users are 21 years or older during signup.
 * It is called by Entra External ID "Before creating the user" API connector.
 *
 * Input: { birthdate: "YYYY-MM-DD", email: "user@example.com" }
 * Output: { action: "Continue" | "ShowBlockPage", extension_age_verified: true }
 *
 * Privacy: Birthdate is NOT stored. Only age_verified boolean is returned.
 */

module.exports = async function (context, req) {
    context.log('Age verification request received');

    const { birthdate, email } = req.body;

    // Validate birthdate is provided
    if (!birthdate) {
        context.log.error('Missing birthdate in request');
        context.res = {
            status: 400,
            body: {
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "Date of birth is required. Please try again."
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
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "Please enter a valid birthdate in YYYY-MM-DD format."
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
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "Please enter a valid date."
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
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "You must be 21 years or older to use MyBartenderAI. This app is intended for adults of legal drinking age only."
            }
        };
        return;
    }

    // User is 21+, allow signup and set age_verified flag
    context.log(`User is 21+ (age: ${age}), allowing signup with age_verified=true`);

    context.res = {
        status: 200,
        body: {
            version: "1.0.0",
            action: "Continue",
            extension_age_verified: true  // This becomes the age_verified claim in JWT
            // NOTE: We do NOT return the birthdate to preserve privacy
        }
    };
};
