# Test Lambda deployment

## Build

```shell
docker build --platform linux/amd64 -t test-lambda:test .
```

## Test

```shell
docker run --platform linux/amd64 -p 9000:8080 test-lambda:test
```

In a separate terminal:

```console
$ curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
"Hello from AWS Lambda using Python3.12.7 (main, Oct 14 2024, 11:21:50) [GCC 11.4.1 20230605 (Red Hat 11.4.1-2)]!"
```

## Deploy

```shell
aws ecr get-login-password | docker login --username AWS --password-stdin 732829343588.dkr.ecr.us-east-2.amazonaws.com
aws ecr create-repository --repository-name test-lambda --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE
docker tag test-lambda:test 732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest
docker push 732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest
aws iam create-role --role-name lambda-basic-exec \
    --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name lambda-basic-exec --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws lambda create-function \
  --function-name test-lambda --package-type Image \
  --code ImageUri=732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest \
  --role arn:aws:iam::732829343588:role/lambda-basic-exec
```

## Test deploy

```shell
aws lambda invoke --function-name test-lambda response.json
cat response.json | jq
```

## Update

```shell
docker build --platform linux/amd64 -t 732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest .
docker push 732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest
aws lambda update-function-code \
  --function-name test-lambda \
  --image-uri 732829343588.dkr.ecr.us-east-2.amazonaws.com/test-lambda:latest \
  --publish
```
