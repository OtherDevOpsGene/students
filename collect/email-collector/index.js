/**
 * AWS Lambda function that collects an email address and stores it in DynamoDB
 * To use this Lambda function, you'll need to:

Create a DynamoDB table and set its name in an environment variable DYNAMODB_TABLE
Configure the appropriate IAM role with permissions for DynamoDB access
Set up an API Gateway trigger to expose the Lambda function as an HTTP endpoint

The Lambda function includes:

Input validation
Error handling
CORS headers (configure for your domain)
Timestamp recording
DynamoDB integration
Response formatting

claude ai prompt: write an aws lambda function to collect an email address from
a web page and then store the result in a dynamodb table
 */

const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    try {
        // Parse the incoming request body
        const body = JSON.parse(event.body);
        const email = body.email;
        
        // Validate email
        if (!email || !isValidEmail(email)) {
            return {
                statusCode: 400,
                headers: {
                    'Access-Control-Allow-Origin': '*', // Configure this for your domain
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message: 'Invalid email address'
                })
            };
        }
        
        // Create timestamp for record
        const timestamp = new Date().toISOString();
        
        // Prepare DynamoDB parameters
        const params = {
            TableName: process.env.DYNAMODB_TABLE,
            Item: {
                email: email,
                subscriptionDate: timestamp,
                // Add a composite key if needed
                id: `${email}_${timestamp}`
            }
        };
        
        // Store in DynamoDB
        await dynamoDB.put(params).promise();
        
        // Return success response
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*', // Configure this for your domain
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: 'Email subscription successful',
                email: email
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        // Return error response
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*', // Configure this for your domain
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: 'Internal server error'
            })
        };
    }
};

// Email validation helper function
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}
