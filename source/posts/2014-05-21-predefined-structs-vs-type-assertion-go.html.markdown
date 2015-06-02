---
title: Predefined Structs vs Type Assertion in Go
date: 2014-05-21
tags: golang
---

Suppose you have a JSON of this format:

```
{
  "results": 
    "collection": [
      {
        "name": { first_name: "Ho Man", last_name: "Boa"
        "phone": "123456"
      },
      {
        "name": { first_name: "John", last_name: "Lee"
        "phone": "2345"
      }
    ]
}
```

### Similarities 

There are essentially 2 methods to do this, using pre-defined structs or using type assertion. The only similar part is where the data is converted into []bytes for later use.

```go
 data, err := ioutil.ReadAll(dataStream)
 if err != nil {
  panic(err)
 }
```



### Type Assertion

I personally don't like this method because you end up doing a lot of manipulation in the end anyways but it could be helpful if you don't want to define the entire structure right from the beginning or if your final structure is vastly different from the format of the original JSON.

The general idea is to read it into a generic interface -> then slowly step by step cast it into moar interfaces. e.g.

**First define the final structure you want the results to be in and `Unmarshal` the JSON into a blank `interface{}`**

```go
type Person struct {
  FullName  string
  Phone     string
}
var i interface{}
json.Unmarshal(data, &i)
```

**Type assert `results/collection` into an array of interfaces{} and create a `slice` to hold the final data. **

```go
m := i.(map[string]interface{})
people := m["results"].(map[string]interface{})["collection"].([]interface{})
peopleSlices := make([]Person, len(people))
```

**Loop through the slice and further type assert the generic interface{} objects into their corresponding data types. You can also employ the type switch technique that is described here (http://golang.org/doc/effective_go.html#type_switch) to do this instead of setting it in stone.**

```go
for i, value := range people {
 person := value.(map[string]interface{})
 name := person["name"].(map[string]interface{})
 phone := person["phone"].(string)

 peopleSlices[i] = Person{
  FullName: name["first_name"].(string) + name["last_name"].(string)
  Phone: phone
 }
}
```

### Pre-defined Structs

This method seems to be the more conventional way. The problem with this is that if your desired format is vastly different from the original JSON format, you basically have to define 2 sets of structs. **On the bright side, the code is much much cleaner**

**Define the format of the *initial JSON* into a var struct{}.**

```go
var People struct {
  Results struct {
   Collections []struct {
     Name struct {
       First_name string
       Last_name  string
     },
     Phone string
   }
  }
}
```

**Simply Unmarshal it and profit! How simple is that?**

```go
json.Unmarshal(body, &People)
```







