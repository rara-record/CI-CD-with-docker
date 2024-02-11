# 목적 
AWS 인프라스트럭쳐 환경 Next.js 프로젝트 CI.CD 환경 구성

# 요구 사항
1. Next.js 프로젝트를 Dockerize 하여 AWS ECR에 push 되어야 한다.
   - https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile 
   - Image size 감소를 위해 next.config.js 파일에 output: ‘standalone’ 항목이 추가
2. AWS ECR push 이후, deployment 가 수행될 script가 작성되어야 한다.
   - 스크립트 파일명은 deploy.sh 로 
   - 해당 스크립트는 압축되어서 s3 로 업로드
3. AWS CodeDeploy를 통해서 해당 스크립트가 수행되도록 한다.
4. EC2 인스턴스 에는 docker가 사전 설치 되어 있어야 한다.
5. GitHub에서 사용하는 IAM role
   - S3에 put 권한
   - ECR push 권한
   - CodeDeploy create deploy 권한
6. EC2 에서 사용되는 IAM role
   - s3의 object 를 get, list
   - ECR image list, read

# 추가 해보기
- AutoScalingGroup 를 활용한 로드밸런싱을 진행
- Blue/Green 정책을 이용한 무중단 배포를 진행