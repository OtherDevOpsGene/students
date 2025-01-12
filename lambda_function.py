import boto3
import re
import datetime
import os
import logging
from botocore.exceptions import ClientError
from flask import Flask, render_template, request, flash, redirect, url_for
import awsgi

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('username_collector')

# Load environment variables with defaults
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE', 'usernames')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-2')
FLASK_SECRET_KEY = os.getenv('FLASK_SECRET_KEY', os.urandom(24))
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Set log level from environment variable
logger.setLevel(getattr(logging, LOG_LEVEL.upper()))

app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY

class UsernameCollector:
    def __init__(self, table_name=DYNAMODB_TABLE, region=AWS_REGION):
        """Initialize DynamoDB connection and ensure table exists."""
        self.logger = logging.getLogger('username_collector.UsernameCollector')
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table_name = table_name
        self.logger.info("Initializing UsernameCollector with table: %s in region: %s", 
                        self.table_name, region)
        self.ensure_table_exists()
    
    def ensure_table_exists(self):
        """Create the DynamoDB table if it doesn't exist."""
        try:
            # Check if table exists
            self.dynamodb.Table(self.table_name).table_status
            self.logger.info("Table %s exists", self.table_name)
        except ClientError:
            self.logger.info("Table %s does not exist. Creating...", self.table_name)
            try:
                # Create table if it doesn't exist
                table = self.dynamodb.create_table(
                    TableName=self.table_name,
                    KeySchema=[
                        {
                            'AttributeName': 'username',
                            'KeyType': 'HASH'
                        }
                    ],
                    AttributeDefinitions=[
                        {
                            'AttributeName': 'username',
                            'AttributeType': 'S'
                        }
                    ],
                    ProvisionedThroughput={
                        'ReadCapacityUnits': 5,
                        'WriteCapacityUnits': 5
                    }
                )
                # Wait for table to be created
                table.meta.client.get_waiter('table_exists').wait(TableName=self.table_name)
                self.logger.info("Table %s created successfully", self.table_name)
            except Exception as e:
                self.logger.error("Failed to create table %s: %s", self.table_name, str(e))
                raise

    def check_duplicate_username(self, username):
        """
        Check if username already exists in DynamoDB table.
        Returns True if username exists, False otherwise.
        """
        table = self.dynamodb.Table(self.table_name)
        try:
            response = table.get_item(
                Key={
                    'username': username.lower()
                },
                ProjectionExpression='username'  # Only retrieve the username field
            )
            exists = 'Item' in response
            if exists:
                self.logger.info("Duplicate username found: %s", username)
            return exists
        except Exception as e:
            self.logger.error("Error checking for duplicate username %s: %s", username, str(e))
            raise

    def validate_username(self, username):
        """
        Validates a username according to the following rules:
        - Max 64 characters
        - Allowed chars: A-Z, a-z, 0-9, +, =, ., _, -
        Returns True if valid, False otherwise
        """
        import re
        pattern = r'^[A-Za-z0-9+=._-]{1,64}$'
        return bool(re.match(pattern, username))

    def store_username(self, username):
        """Store username in DynamoDB."""
        if not self.validate_username(username):
            raise ValueError("Invalid username format")
        
        # Normalize username to lowercase
        username = username.lower()
        
        # Check for duplicate before attempting to store
        if self.check_duplicate_username(username):
            self.logger.warning("Attempted to store duplicate username: %s", username)
            raise ValueError("This username address is already registered")
        
        table = self.dynamodb.Table(self.table_name)
        try:
            response = table.put_item(
                Item={
                    'username': username
                }
            )
            self.logger.info("Successfully stored username: %s", username)
            return True
        except Exception as e:
            self.logger.error("Failed to store username %s: %s", username, str(e))
            raise

    def get_user_data(self, username):
        try:
            table = self.dynamodb.Table(self.table_name)
            response = table.get_item(
                Key={'username': username}
            )
            
            exists = 'Item' in response
            if exists:
                return jsonify(response['Item'])
            return jsonify({'error': 'User not found'}), 404
            
        except ClientError as e:
            logger.error(f"Error retrieving user data: {e}")
            return jsonify({'error': 'Database error occurred'}), 500

# Create a global usernameCollector instance
collector = UsernameCollector()

@app.route('/')
def index():
    """Render the main page."""
    return render_template('index.html')

@app.route('/submit', methods=['POST'])
def submit_username():
    """Handle username submission."""
    username = request.form.get('username', '').strip()
    logger.info("Received submission request for username: %s", username)
    
    try:
        collector.store_username(username)
        flash('username successfully registered!', 'success')
        return redirect(url_for('success'))
    except ValueError as e:
        logger.warning("Validation error for username %s: %s", username, str(e))
        flash(str(e), 'error')
        return redirect(url_for('index'))
    except Exception as e:
        logger.error("Unexpected error processing username %s: %s", username, str(e))
        flash('An unexpected error occurred. Please try again later.', 'error')
        return redirect(url_for('index'))

@app.route('/success/<username>')
def success(username):
    """Render the success page."""
    return render_template('success.html', username=username)

def handler(event, context):
    logger.info("Starting application with DynamoDB table: %s", DYNAMODB_TABLE)
    return awsgi.response(app, event, context)
