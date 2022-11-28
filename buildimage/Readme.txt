* To build an image run following command, assuming dokcerfile name is Dockerfile: 
	docker image build -t bridge_amz . 

* To upload image to public docker registry of Chandresh 
   docker tag bridge_amz chapatel/bridge_amz:v1
   docker push chapatel/bridge_amz:v1

* To upload image to AWS ECR: 
	1.	Create ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html
	2.	Docker login to ECR using: 
	        aws ecr get-login-password --region us-west-2 --profile saml | docker login --username AWS --password-stdin 010465704656.dkr.ecr.us-west-2.amazonaws.com
        3. 	Tag the local image : 
		docker tag bridge_amz 010465704656.dkr.ecr.us-west-2.amazonaws.com/bridge:v1
	4. 	push the image to ECR: 
		docker push 010465704656.dkr.ecr.us-west-2.amazonaws.com/bridge:v1 
