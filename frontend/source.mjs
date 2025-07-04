import express from 'express';
import path from 'path';
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import { fileURLToPath } from 'url';

const app = express();
const PORT = process.env.PORT || 8080; 


const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);


app.use(express.json());


app.use(express.static(path.join(__dirname, 'public')));


const client = new DynamoDBClient({ region: 'us-east-2' }); 

app.post('/visit', async (req, res) => {
  try {
    const { userAgent } = req.body;
    const timestamp = new Date().toISOString();
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    const params = {
      TableName: 'site_visits',
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


app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running at http://localhost:${PORT}`);
});