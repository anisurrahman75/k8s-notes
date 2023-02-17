## What is a Job?
- Job is a controller which supervises pods of carrying out certain tasks at high level
- Used to run short-lives, one-off tasks
- Jobs are useful for things you only want to do once, such as database migrations or batch jobs.


## Types of jobs


- Run to completion -Jobs

    - Each job creates one or more pods

    - Ensures they are successfully terminated

    - Job controller restarts or rescheduled if a pod or node failed during execution

    - Job can run multiple pods in parallel

    - Can scaling using kubectl scale command

    - Use cases:

      - One time initialization of resources such as Databases
      - Multiple worker to process messaging in queue

- Scheduled  -CronJob


## Manifest file
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: countdown
spec:
  completions: 2
  parallelism: 2
  template:
    metadata:
      name: countdown
    spec:
      containers:
        - name: counter
          image: centos:7
          command: ["echo","hello i am from countdown job pod"]
      restartPolicy: Never

```
## Create and Display

- $ kubectl create -f &lt;jobs_file_names>
- $ kubectl logs <pod_name>


## Completions and Parallelism
 
```yaml
        ...
        spec:
        completions: 10
        parallelism: 5
        template:
        ...
        
   ```
-   If we set completions: 10, then it run 10 pods one after another
-   If we set parallelism: 5, then it will run parallelly 5 pods

## Backoff Limit
-   If a pod fails, then new pods is created until it is created successfully.
  -   But it can take infinit times for some error.
  Lets change the yaml file like below
  ```yaml
...
spec:
  backoffLimit: 2
    ...
    spec:  
      containers:
      - name: counter
        image: centos:7
        command: ["ls","/anisur"]
...

```



-   This jobs pods are failing once after another until success
-   then failure pods are create until backoff limit cross  
## Active Deadline
-   If we know that our job will not take more than a specific time, then we can set activeDeadlineSeconds to terminate our job after a specific time.


```yaml
...
spec:
    activeDeadlineSeconds: 10
    template:
    ...
            command: ["sleep", "30"]
    ...
...

```

-   Now run the below command to see the events
-   $ kubectl describe jobs | less

## Cronjob
-   Sometimes we want to schedule a job to be run at a certain interval.
-   To achieve this, we can declare a CronJob in Kubernetes, which is responsible for creating a new Job object at a particular interval
```yaml
# cron-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
    name: helloworld
spec:
    schedule: "* * * * *"
    jobTemplate:
        spec:
            template:
                spec:
                    containers:
                    - name: busybox
                      image: busybox
                      command: ["echo", "Hello Kubernetes!!!"]
                    restartPolicy: Never


```
## To delete cronjobs
-   $ kubectl delete cronjob  helloworld
