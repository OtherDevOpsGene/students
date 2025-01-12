/**
 * Lambda function that looks up email records from DynamoDB based on a query parameter.
 * 
 * To set this up:

Make sure your DynamoDB table has 'email' as the partition key
Configure an API Gateway with a GET method
Set up the appropriate IAM role with DynamoDB read permissions
Set the DYNAMODB_TABLE environment variable in your Lambda configuration

The function includes:

Query parameter validation
Error handling
CORS support
Proper DynamoDB querying
Formatted JSON responses

The function will return:

400 if no email is provided
404 if the email isn't found
500 for server errors
200 with the records if found

claude ai prompt:
write an aws lambda function to lookup an email address from an html parameter
and return the results from a dynamodb table 
 */

const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    try {
        // Get email from query parameters
        const email = event.queryStringParameters?.email;
        
        if (!email) {
            return {
                statusCode: 400,
                headers: {
                    'Access-Control-Allow-Origin': '*', // Configure this for your domain
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message: 'Email parameter is required'
                })
            };
        }
        
        // Prepare DynamoDB query parameters
        const params = {
            TableName: process.env.DYNAMODB_TABLE,
            KeyConditionExpression: 'email = :email',
            ExpressionAttributeValues: {
                ':email': email
            }
        };
        
        // Query DynamoDB
        const result = await dynamoDB.query(params).promise();
        
        if (result.Items.length === 0) {
            return {
                statusCode: 404,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message: 'Email not found'
                })
            };
        }
        
        // Return the found records
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: 'Records found',
                records: result.Items
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: 'Internal server error'
            })
        };
    }
};
