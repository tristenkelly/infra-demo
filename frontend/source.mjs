import express from 'express';
import path from 'path';
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 8080; // Changed port here

// For __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Middleware to parse JSON bodies
app.use(express.json());

// Serve static files from the frontend directory
app.use(express.static(path.join(__dirname, 'public')));

// DynamoDB client (ensure your EC2 has IAM permissions for DynamoDB)
const client = new DynamoDBClient({ region: 'us-east-2' }); // Set your region

app.post('/visit', async (req, res) => {
  try {
    const { userAgent } = req.body;
    const timestamp = new Date().toISOString();
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    const params = {
      TableName: 'site-visits', // Your DynamoDB table name
      Item: {
        visit_id: { S: uuidv4() },
        timestamp: { S: timestamp },
        userAgent: { S: userAgent || '' },
        ip: { S: ip || '' },
      },
    };

    await client.send(new PutItemCommand(params));
    res.status(200).json({ status: 'logged' });
  } catch (error) {
    console.error('Error writing to DynamoDB:', error);
    res.status(500).json({ error: 'Failed to log visit' });
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});