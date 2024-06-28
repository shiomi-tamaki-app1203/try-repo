import { APIGatewayProxyHandler } from 'aws-lambda';
import { RDS } from 'aws-sdk';

const rds = new RDS();

export const handler: APIGatewayProxyHandler = async (event, context) => {
  // Your logic here
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Hello from Lambda!',
    }),
  };
};

