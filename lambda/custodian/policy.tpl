{
  "execution-options": {},
  "policies": [
    {
      "name": "StartAt6",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "stopped"
        },
        {
          "tag:ScheduleStart": "6"
        },
        {
          "type": "onhour",
          "tag": "ScheduleStart",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "onhour": 6
        }
      ],
      "actions": [
        "start"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "StartAt7",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "stopped"
        },
        {
          "tag:ScheduleStart": "7"
        },
        {
          "type": "onhour",
          "tag": "ScheduleStart",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "onhour": 7
        }
      ],
      "actions": [
        "start"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "StartAt8",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "stopped"
        },
        {
          "tag:ScheduleStart": "8"
        },
        {
          "type": "onhour",
          "tag": "ScheduleStart",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "onhour": 8
        }
      ],
      "actions": [
        "start"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "StopAt17",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "running"
        },
        {
          "tag:ScheduleStop": "17"
        },
        {
          "type": "offhour",
          "tag": "ScheduleStop",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "offhour": 17
        }
      ],
      "actions": [
        "stop"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "StopAt18",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "running"
        },
        {
          "tag:ScheduleStop": "18"
        },
        {
          "type": "offhour",
          "tag": "ScheduleStop",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "offhour": 18
        }
      ],
      "actions": [
        "stop"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "StopAt19",
      "resource": "ec2",
      "filters": [
        {
          "State.Name": "running"
        },
        {
          "tag:ScheduleStop": "19"
        },
        {
          "type": "offhour",
          "tag": "ScheduleStop",
          "weekends": false,
          "opt-out": true,
          "default_tz": "cet",
          "offhour": 19
        }
      ],
      "actions": [
        "stop"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "CustomStop",
      "resource": "ec2",
      "filters": [
        {
          "type": "offhour",
          "tag": "CustomSchedule"
        }
      ],
      "actions": [
        "stop"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    },
    {
      "name": "CustomStart",
      "resource": "ec2",
      "filters": [
        {
          "type": "onhour",
          "tag": "CustomSchedule"
        }
      ],
      "actions": [
        "start"
      ],
      "mode": {
        "type": "periodic",
        "schedule": "${lambda_schedule}",
        "role": "${lambda_role_arn}",
        "tags": {
          "custodian-info": "mode=periodic:version=0.9.31"
        }
      }
    }
  ]
}