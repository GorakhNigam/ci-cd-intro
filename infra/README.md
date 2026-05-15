## Setup

⚠️ _Do not follow these instructions blindly. Please take the time to review the steps and adapt them to your environment._

### 0. Pre-requisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/)
- [Terraform 0.15.x+](https://www.terraform.io/)
- [Packer](https://www.packer.io/)
- [Node.js 14.x](https://nodejs.org/en/)

Clone this repository and follow the instructions below:

### 1. Build the Azure managed image

```sh
cd infra/images
packer build .
```

Once the image has been built you should be able to see it in your Azure portal as a managed image.
![1B7DD86D-AFF4-42E2-AB90-BB8B4618DEA9](https://user-images.githubusercontent.com/568794/125193943-5cabf880-e24f-11eb-9f81-b5e6e27747fa.png)

### 2. Create a RSA keys to use for accessing the instances

You need to create 2 keys, 1 for staging and 1 for production with this command (feel free to change the file names):

```sh
# Create a key pair for the staging environment
ssh-keygen -t rsa -b 4096 -C "ubuntu@staging" -f ~/.ssh/id_staging_cicd

# Create a key pair for the production environment
ssh-keygen -t rsa -b 4096 -C "ubuntu@production"  -f ~/.ssh/id_prod_cicd
```

### 3. Add variables to Terraform Cloud

1. Add the variables below to Terraform Cloud. Feel free to create variable sets and assign them:

   - `base_image_id` (managed image ID from Packer)
   - `location` (example: `eastus`)
   - `resource_group_name` (example: `ci-cd-staging-rg`)
   - `admin_username`
   - `staging_public_key` or `production_public_key`

1. Edit your `main.tf` file and update the `backend` `organization name` and `workspaces` to match your Terraform Cloud organization and workspace:

   ```hcl
   terraform {
      backend "remote" {
         organization = "<YOUR_ORG_NAME>"

         workspaces {
            name = "<YOUR_WORKSPACE_NAME>"
         }
      }
   ```

### 4. Spin up your Azure VM instances from the image we built

```sh
$ cd infra/instances/production

$ terraform init
$ terraform plan
$ terraform apply
```

If all goes well, you should see your VMs in the Azure portal.

Do the same for your staging environment.
