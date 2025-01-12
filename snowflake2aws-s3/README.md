# Backing Up DEV_COMMON Database from Snowflake to S3 Using IAM Role Integration

When managing large databases in Snowflake, having a reliable backup process is essential for business continuity and disaster recovery. At , we needed to set up an automated database backup from Snowflake to an Amazon S3 bucket, specifically for the DEV_COMMON database. In this blog post, we’ll walk through how we set up the process by configuring Snowflake to assume an IAM role for S3 access and resolved the issue of file size limits in single-file mode.

## Steps Overview
1. Create an IAM Policy and Role in AWS
2. Configure Snowflake Storage Integration
3. Create an External Stage in Snowflake
4. Set Up the Stored Procedure for Database Backup
5. Resolve the Max File Size Issue in Single-File Mode

Let’s dive into each step.

### Step 1: Create an IAM Policy and Role in AWS

The first step is to create an IAM policy in AWS that grants permission to write data into your S3 bucket. This policy will be attached to an IAM role that Snowflake can assume.

#### Create the IAM Policy
Navigate to the AWS IAM console and create a new policy with the following JSON:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::snowflake-db-backup-dev/*"
        }
    ]
}
```

This policy grants permission to upload objects to a specific S3 bucket (`snowflake-db-backup-dev`).

#### Create the IAM Role
Next, create a role in AWS that Snowflake can assume.

1. Under **Trusted entities**, select **Another AWS account** and use the Snowflake account ID. This can be obtained from Snowflake by running:

   ```sql
   DESC INTEGRATION <your_integration_name>;
   ```

   Here you’ll find the `STORAGE_AWS_IAM_USER_ARN` value to use in the trust relationship.

2. Attach the previously created policy to this role. The trust policy should look like this:

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "AWS": "arn:aws:iam::snowflake_account_id:root"
               },
               "Action": "sts:AssumeRole",
               "Condition": {
                   "StringEquals": {
                       "sts:ExternalId": "your_external_id"
                   }
               }
           }
       ]
   }
   ```

3. After the role is created, note down the **Role ARN** (Amazon Resource Name), as this will be used later in Snowflake to configure storage integration.

---

### Step 2: Configure Snowflake Storage Integration

In Snowflake, we configure a storage integration that allows Snowflake to assume the IAM role you created in AWS. This enables Snowflake to access your S3 bucket without directly managing access keys.

#### Create the Storage Integration in Snowflake

```sql
CREATE OR REPLACE STORAGE INTEGRATION s3_backup_integration
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = 'S3'
STORAGE_AWS_ROLE_ARN = '<your_aws_role_arn>'
STORAGE_ALLOWED_LOCATIONS = ('s3://snowflake-db-backup-dev/')
ENABLED = TRUE;
```

This configuration grants Snowflake permission to assume the IAM role and interact with the specified S3 bucket.

---

### Step 3: Create an External Stage in Snowflake

The external stage in Snowflake specifies the S3 bucket where the data will be unloaded.

```sql
CREATE OR REPLACE STAGE s3_backup_stage 
URL = 's3://snowflake-db-backup-dev/'
STORAGE_INTEGRATION = s3_backup_integration
FILE_FORMAT = (TYPE = 'CSV');
```

This stage will be referenced in the backup procedure to export data from Snowflake tables to S3 in CSV format.

---

### Step 4: Set Up the Stored Procedure for Database Backup

With the integration in place, we can now automate the backup of tables in the `DEV_COMMON` database using a JavaScript stored procedure.

You can find the stored procedure that we implemented to export each table to S3 inside this repository.

---

### Step 5: Resolve Max File Size Issue in Single-File Mode

During our initial implementation, we encountered errors due to the default file size limit of 16 MB in Snowflake’s single-file mode. To resolve this, we adjusted the stored procedure to disable single-file mode and increase the file size limit:

- **Increase max file size to 5 GB**:

  ```sql
  MAX_FILE_SIZE = 5368709120
  ```

- **Disable single-file mode**:

  ```sql
  SINGLE = FALSE
  ```

This adjustment allowed us to export larger tables without hitting file size limits.

---

## Conclusion

By integrating Snowflake with AWS S3 using IAM roles and configuring our backup process, we now have a seamless and scalable database backup solution. The Snowflake IAM role assumption and handling of large file sizes ensure that our backups run smoothly and efficiently, storing each day’s backups in separate folders on S3. We also added logging for better visibility into backup success and errors.

This setup can easily be adapted to other databases or modified to suit additional backup requirements.
