# Filtering logs:
 
There may come a time where a log is not particularly useful or an aspect of LME proves overly verbose (e.g.: [Dashboard spamming events](https://github.com/cisagov/LME/issues/22). We try our best to make everything useful by default but cannot predict every eventuality since all environments will be different. So to enable users to make the LME system more useful (and hopefully commit their own pull requests back with updates :) ), we are documenting here how you can filter out logs in the:

1. Dashbaord
2. Host logging utility (e.g. winlogbeat)
3. Serverside (e.g. logstash)

Have fun reading and applying these concepts 

## Dashboard:

The below example shows a filter that can be applied to a search, and saved with a dashboard to filter out unneeded windows event log [4624](https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4624) with a TargetUserName field that has a `$ `. 
```
{
  "bool": {
    "filter": [
      {
        "match_phrase": {
          "event.code": "4624"
        }
      }
    ],
    "must_not": [
      {
        "regexp": {
          "winlog.event_data.TargetUserName": ".*$.*"
        }
      }
    ]
  }
}
```

To Add:
1. Click the `Add filter`:
2. Click `Edit as DSL` to add a regexp filter:

More resources on this topic can be found here, and there are many more relevant examples on stackoverflow:
 - https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
 - https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#query-string-syntax
 - https://www.elastic.co/guide/en/elasticsearch/reference/current/regexp-syntax.html

## Host Side:
```
TBD Pending testing
```

## Server Side:
```
TBD Pending testing
```
