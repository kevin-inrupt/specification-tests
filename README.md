# Solid Specification Conformance Tests

<!-- MarkdownTOC -->

- [Running these tests locally](#running-these-tests-locally)
- [KarateDSL](#karatedsl)
  - [Structure of a test case](#structure-of-a-test-case)
  - [Data related keywords](#data-related-keywords)
  - [HTTP related keywords](#http-related-keywords)
  - [Karate object](#karate-object)
  - [Calling functions](#calling-functions)
- [Test harness capabilities](#test-harness-capabilities)
  - [Global variables](#global-variables)
  - [Helper functions](#helper-functions)
  - [Libraries](#libraries)
- [Example test cases](#example-test-cases)
- [Specification annotations](#specification-annotations)
- [Test manifest](#test-manifest)

<!-- /MarkdownTOC -->

This repository contains the tests that can be executed by the
[Solid Conformance Test Harness](https://github.com/solid/conformance-test-harness). The best way to run the harness is
by using the [Docker image](https://hub.docker.com/r/solidconformancetestbeta/conformance-test-harness).

The tests are written in a language called KarateDSL. This is a simple BDD testing language based on 
[Gherkin](https://cucumber.io/docs/gherkin/) but which has been extended specifically for testing HTTP APIs. Further
Solid-specific capabilities are added by the test harness. The difference to Cucumber's use of Gherkin is that this is
actually executable code rather than just a human readable layer on top of functions that the tester must write. It also
has an embedded JavaScript engine supporting ES6 syntax and provides the ability to call Java classes. The conformance 
tests are expected to be written in KarateDSL and JavaScript. Additional capabilities added to the test harness as Java
libraries will be called from these without the need for the test implementer to know Java.

# Running these tests locally
You can clone this repository, work on tests and run them locally using the docker image:
```shell
git clone git@github.com:solid/specification-tests.git
cd specification-tests
````
Create `.env` in this directory according to these instructions 
[here](https://hub.docker.com/r/solidconformancetestbeta/conformance-test-harness)
Modify the script `run.sh` to use the target subject you are testing and run it: 
```shell
./run.sh
```
The reports will be created in the `reports/` directory.

If you want to only run specific test(s) you can add the filter option:
```shell
./run.sh --filter=content-negotiation
```

# KarateDSL

The following is a high level overview of Karate, focussed on the most common aspects required in these specification
tests. For more detail please go to:
* [KarateDSL](https://intuit.github.io/karate/)
* [Syntax Guide](https://intuit.github.io/karate/#syntax-guide)

This gherkin

## Structure of a test case
The basic structure is:
```gherkin
Feature: The title of the test case

  Background: Set up steps performed for each Scenario
    * def variable = 'something'

  Scenario: The title of the scenario
    Given url 'https://example.org/test.ttl'
    And header Content-Type = 'text/turtle'
    When method GET
    Then status 200
    And match header Content-Type contains 'text/turtle'
    And match response contains 'some-text'

  Scenario: The title of another scenario
    * another set of steps
```

The keywords `Given`, `And`, `When`, and `Then` in the scenario are for the benefit of human readers of the script, to 
the test harness they simply denote steps in the procedure and have the same meaning as `*`. They make it easier for
anyone to gain an understanding of the test.

The `Background` steps are executed before every `Scenario` in the file. This is important to understand as it allows
the scenarios to be run in parallel but can also cause confusion if you expect a scenario to depend on something done
in a previous scenario. If you need to perform a sequence of interactions in a single test then they should all be added
to the same scenario. It is important to think of each scenario as a `Test` and the background as a `BeforeEach` method
as you might see in other testing frameworks.

The first scenario represents a single HTTP interaction with the server with the following conceptual structure:
* Start with any variables you need to set up - normally this is done with a `*` prefix.
* Then use `Given` to start describing the context for the test. Often this will be where you set up the URL or path for
  the interaction.
* Use `And` to provide more details for the context e.g. setting up request headers.
* The `When` keyword represents the action but remember it has the same meaning as `*`. The request is actually
  triggered by the use of `method`.
* Next you can begin to make assertions about the response starting with the `Then` keyword and often checking the
  status first.
* Finally you can use `And` to describe additional assertions. You could use `*` if you need to create variables and
  analyze the response and reserve `And` for assertions but of course it is a style choice since the keywords have no
  meaning to the test harness as already stated.
  
## Data related keywords

* `def` set a variable: `* def myVar = 'text'`
* `assert` assert an expression evaluates to `true`: `* assert myVar == 'text'` 
* `print` log to the console: `* print 'myVar = ' + myVar`

JSON and XML are supported directly so you can express things such as:
```gherkin
* def cat = { name: 'Billie', color: 'black' }
* assert cat.color == 'black'
* def myCat = <cat><name>Billie</name><color>black</color></cat>
* assert myCat.cat.color == 'black'
```

When handling large amounts of data you can either read it in from external files or express it on multiple lines
using `"""`. This can apply to commands such as `def`, `request`, `match`:
```gherkin
* def cat =
  """
  {
    name: 'Billie',
    color: 'black'
  }
  """
```

Karate attempts to parse the multiline data so if you need to avoid this you can use the `text` keyword instead of
`def`. This is particularly useful when you have Turtle data that it thinks might be malformed XML.
```gherkin
* text data =
  """
  @base <https://example.org> .
  <#hello> <#linked> <#world> .
  """
```

To read data from an external file there is a `read` keyword however this attempts to parse the data as JSON or XML so
to get raw data you should use a karate function as follows:
```gherkin
* def data = karate.readAsString('../fixtures/example.ttl')
```

## HTTP related keywords
### Setting the URL
There are 2 keywords for setting the URL to be used in a request: `url` and `path`. The full URL can be set in the 
background. It is good practice to use the `*` keyword int he background and the `Given` keyword in a scenario.
```gherkin
* url 'https://example.org/test`
```
You could set a base url in the background which applies to all scenarios and then use the `path` keyword to alter it
for each scenario:
```gherkin
* url 'https://example.org/`
Given path 'test'
```
An alternative would be to set the base URL as a variable in the background and use `url` in the scenarios:
```gherkin
* def baseUrl = 'https://example.org/`
Given url baseUrl + 'test1'
```

### Configuring the request
The keywords: `param`, `header`, `cookie`, `form field` and `multipart field` are used for setting key-value pairs in 
the relevant part of the request.
```gherkin
And param key = "value" # adds ?key=value to the query string
And header Accept = 'text/turtle'
And cookie foo = 'bar'
And form field username = 'john'
```
You can set multiple values at the same time with JSON using `params`, `headers`, `cookies` and `form fields`.
Note:
* that these keywords can take expressions or functions which return a single value or a map for the multiple value
versions.
* these commands are additive - the key-value pair(s) are added to the request.
* the key is not in quotes in the single key-value variants

If you want to set up some headers to be used across multiple requests you can use the following command:
```gherkin
* configure headers = { 'Content-Type': 'application/json' }
```
If you use this in the `Background` it will apply to all scenarios so if you need to replace these headers in on of 
those scenarios you will need to configure them again in the same way or configure the headers as null and set them as
normal.

### Setting the request body
To set up the body of the request use the `request` keyword. Note that for methods that expect a body (e.g. PUT, POST)
you must use this keyword even if you set the content as an empty string. You would normally be using this in
conjunction with the `And` keyword: 
```gherkin
And request 'data'
And request ''
And request { name: 'Billie', color: 'black' }
And request karate.readAsString('../fixtures/example.ttl')
```

### Sending the request
The HTTP request is sent when you use the `method` keyword and a specific method. You would normally use this in
conjunction with the `When` keyword:
```gherkin
When method PUT
```

### Checking the response code
Finally, there is a shorthand for asserting the value of the response code if you are only matching one code:
```gherkin
Then status 200
```
In cases where you need to match multiple possible codes you need to revert to using the `responseStatus` variable.
```gherkin
* Then match [200, 201, 202] contains responseStatus
* Then assert responseStatus >= 200 && responseStatus < 300
* Then match karate.range(200, 299) contains responseStatus
```
Note that the last option creates and array of 100 values so the error message in not particularly helpful as it lists
all the options that the code did not match!

### Checking the response payload
The important keywords for this are `match` and `assert`. They are very similar but generally `match` should be used as
it is better at reporting errors than `assert`. The `match` keyword is very powerful and has the ability to ignore parts
of the data when matching and to apply fuzzy matching. The full details are available here:
[Payload Assertions](https://intuit.github.io/karate/#payload-assertions)

In their simplest forms `match` and `assert` simply take a JavaScript expression that evaluates to a boolean:
```gherkin
* match foo == bar && foo2 != 10
```
The left side can be a variable name, a JSON/XML path, a function call or anything in parentheses which evaluates as
JavaScript. The right side can be any [Karate expression](https://intuit.github.io/karate/#karate-expressions). Some of
the important operators are outlined below

#### `contains`
This can be a simple text comparison:
```gherkin
* match hello contains 'World'`
* match hello !contains 'World'`
```
It can also work with arrays and maps:
```gherkin
* def foo = { bar: 1, baz: ['hello', 'world'] }
* match foo contains { bar: 1 }
* match foo.baz contains 'world'
```
For matching the contents of an array independent of order:
```gherkin
* def data = { foo: [1, 2, 3] }
* match data.foo contains only [2, 3, 1]
* match data.foo contains any [9, 2, 8]
```
The `any` operator works with objects too:
```gherkin
* def data = { a: 1, b: 'x' }
* match data contains any { b: 'x', c: true }
```
If you want to match deeper into an object you need `contains deep`:
```gherkin
* def original = { a: 1, b: 2, c: 3, d: { a: 1, b: 2 } }
* def expected = { a: 1, c: 3, d: { b: 2 } }
* match original contains deep expected
```

#### Special variables
You can access various parts of the HTTP response using special variables such as `response`, `responseHeaders`, and
`responseStatus`.

The response body is saved into `response` after a request and depending on the content type returned will be a string,
JSON or XML object. You can apply matches to this or perform other logic on it.
```gherkin
* match response contains 'Billie'
* match response.name == 'Billie' # if the response is JSON
```

The headers are available as `responseHeaders` however this can be tricky to use. It is a map of all the header values
in the form `Map<String, List<String>>` and it preserves the case of the returned header names even though they should
be treated as case insensitive. Because of this there is a shortcut `header` which matches the header name 
case-insensitively and matches any value of that key. In the example below, the first 3 are equivalent but the 4th
fails:
```gherkin
* match header Content-Type contains 'text/turtle'
* match header content-type contains 'text/turtle'
* responseHeaders['Content-Type'][0] contains 'text/turtle'
* responseHeaders['content-type'][0] contains 'text/turtle'  # fails as responseHeaders['content-type'] returns null
```
Note that it is safer to use `contains` instead of `==` in this case since the header value may contain an encoding
element such as `; charset=UTF-8`.

The `responseStatus` variable as an alternative to `status` was mentioned earlier.

## Karate object
Within a test case you have access to the Karate object which has a number of useful methods described
[here](https://intuit.github.io/karate/#the-karate-object). This includes methods to manipulate data, call functions
with a lock so they only run once, read from files, create loops, handle async calling,   

## Calling functions
See https://intuit.github.io/karate/#code-reuse--common-routines

Sometimes you may want to set up something in the `Background` section that is only done once for all scenarios whereas
the these steps are normally run for every `Scenario`. This would be like the difference between `BeforeEach` and
`BeforeAll` in other testing frameworks. This can be achieved using `callonce`. You can set up a function in the 
`Background` section (or even in another feature file) and on calling it, receive a single object back again. 
```gherkin
  Background: Setup (effectively BeforeAll)
    * def setupFn =
    """
      function() {
        // do some setup
        return something;
      }
    """
    * def something = callonce setupFn
```
Although the `Background` is run for every `Scenario` the function will only be called once.

# Test harness capabilities

## Global variables
The test harness makes some variables available to all tests.

* `rootTestContainer` an instance of `SolidContainer` pointing to the container in which all test files will be created
  for this run of the test suite. This is guaranteed to exist when the tests start and is a unique URL for every run of
  the test suite.
* `clients` an object containing the HTTP clients that are set up for authenticated access by `alice` and `bob`. One of
  these clients will need to be passed to any newly created `SolidContainer` or `SolidResource`. The user names are the
  key e.g. `clients.alice`.
* `webIds` an object containing the webIds of the 2 users. These are needed when setting up ACLs e.g. `webIds.alice`.
* `aclPrefix` the turtle prefixes to be prepended to generated ACL documents 

## Helper functions
### Setting up test containers
* `createTestContainer()` create a SolidContainer object referencing a unique sub-container of the `rootTestContainer`.
  This container will not be created until a resource is created inside it.
* `createTestContainerImmediate()` create a SolidContainer object referencing a unique sub-container of the
  `rootTestContainer` but ensure that it is actually created at this point.

### Generating ACL documents
The following functions are used in various combinations to generate ACL documents.
* `createOwnerAuthorization(ownerAgent, targetUri)`
  * returns an owner's `acl:Authorization` fragment with full access to the target resource
* `createAuthorization(config)`
  * returns an `acl:Authorization` fragment using whichever parts of the config are supplied
  * `config = { authUri, agents, groups, publicAccess, authenticatedAccess, accessToTargets, defaultTargets, modes }`
* `createBobAccessToAuthorization(webID, resourceUri, modes)`
  * returns an `acl:Authorization` for `bob` with `acl:accessTo` and the specified modes
* `createBobDefaultAuthorization(webID, resourceUri, modes)`
  * returns an `acl:Authorization` for `bob` with `acl:default` and the specified modes
* `createPublicAccessToAuthorization(resourceUri, modes)`
  * returns an `acl:Authorization` for any unauthenticated user with `acl:accessTo` and the specified modes
* `createPublicDefaultAuthorization(resourceUri, modes)`
  * returns an `acl:Authorization` for any unauthenticated user with `acl:default` and the specified modes

For example:
```js
const acl = aclPrefix
  + createOwnerAuthorization(webIds.alice, resource.getContainer().getUrl())
  + createBobDefaultAuthorization(webIds.bob, resource.getContainer().getUrl(), 'acl:Write')
  + createPublicDefaultAuthorization(resource.getContainer().getUrl(), 'acl:Read, acl:Append')
```  

### Parsing functions
##### WAC-Allow header
This `parseWacAllowHeader(headers)` function accepts the response headers, locates the `WAC-Allow` header and parses it into a map object. This object
will contain `user` and `public` keys plus any additional groups defined within the header. It extracts all the acccess
modes and adds them as a list to the relevant group. The result can be treated as a JSON object such as:
```json5
{
  user: ['read', 'write', 'append'],
  public: ['read', 'append']
}
```
In a test, it could be used like this:
```gherkin
* def result = parseWacAllowHeader(responseHeaders)
And match result.user contains only ['read', 'write', 'append']
And match result.public contains only ['read', 'append']
```

## Libraries

Most tests will deal with resources and containers (which is a subclass of a resource). These objects are represented
by 2 classes in the test harness: `SolidResouce` and `SolidContainer`. There is also a library for parsing RDF of 
various formats: `RDFUtils`.

### SolidResource
The `SolidResource` class represents a resource or container on the server. Since this is also the base class for
`SolidContainer` it includes methods that are related to containers. It is not common to need use this class directly
in a test as most resources and containers are created from the starting point of the `rootTestContainer`.

#### `SolidResource.create(solidClient, url, body, contentType)`
* A static method that can create a resource on the server
* Parameters
  * solidClient - the authenticated client to use for this request e.g. `clients.alice`
  * url - the absolute url of the resource to create 
  * body - the data to be put in the resource
  * contentType - the content type of ths data
* Returns an instance of `SolidResource`

#### `exists()`
* Was this resource actually created?
* Returns a boolean

#### `setAcl(acl)`
* Create an ACL for this resource
* Parameters
  * acl - the ACL document
* Returns boolean showing success or failure

#### `getUrl()`
* Get the URL of this resource
* Returns a string

#### `getPath()`
* Get the path of this resource relative to the server root
* Returns a string

#### `isContainer()`
* Is this resource a container?
* Returns a boolean 

#### `getContainer()`
* Gets the `SolidContainer` instance representing the parent container of this resource or ultimately returns the root 
container
* Returns a `SolidContainer`

#### `getAclUrl()`
* Get the ACL URL for this resource
* Returns a string

#### `getContentAsTurtle()`
* Get the contents of this URL as a Turtle document
* Returns a string

#### `getAccessControls()`
* Get the access control document/policy
* Returns a string

#### `delete()`
* Delete this resource and if it is a container, recursively its members

### SolidContainer

#### `SolidContainer.create(solidClient, url)`
* A static method that can create a container on the server
* Parameters
  * solidClient - the authenticated client to use for this request e.g. `clients.alice`
  * url - the absolute url of the container to create
* Returns an instance of `SolidResource`

#### `listMembers()`
* Get a list of all the members of this container
* Returns an array of URLs as strings

#### `parseMembers(data)`
* Parse the container content to get a list of all the members
* Parameters
  * data - the Turtle content of the container
* Returns an array of URLs as strings

#### `instantiate()`
* Create this container on the server
* Returns an instance of `SolidContainer` to allow call chaining

#### `generateChildContainer()`
* Create a container as a child of this one using a UUID as the name but do not instantiate it on the server
* Returns an instance of `SolidContainer` to allow call chaining

#### `generateChildContainer(suffix)`
* Create a `SolidResource` as a child of this container using a UUID as the name with the provided suffix, but do not
  instantiate it on the server
* Parameters
  * suffix - the filename extension to use or a blank string if not needed e.g. `'.ttl'`
* Returns an instance of `SolidResource` to allow call chaining

#### `createChildResource(suffix, body, contentType)`
* Create a `SolidResource` as a child of this container using a UUID as the name with the provided suffix, then put the
  provided contents into it
* Parameters
  * suffix - the filename extension to use or a blank string if not needed e.g. `'.ttl'`
  * body - the data to be put in the resource
  * contentType - the content type of ths data
* Returns an instance of `SolidResource`

#### `deleteContents()`
* Recursively delete the contents of this container but not the container itself

### RDFUtils
KarateDSL 'natively' supports JSON and XML but sadly it does not yet support RDF. As a result you will need a library
to parse RDF documents into formats that are useful for comparisons.

#### `turtleToTripleArray(data, baseUri)`
* Parses a Turtle document into an array of triples
* Parameters
  * data - the Turtle data
  * baseUri - the base URI used for any relative IRIs
* Returns an array of strings in the form `<subject> <predicate> <object> .`

#### `jsonLdToTripleArray(data, baseUri)`
* Parses a JSON-LD document into an array of triples
* Parameters
  * data - the JSON-LD data
  * baseUri - the base URI used for any relative IRIs
* Returns an array of strings in the form `<subject> <predicate> <object> .`

#### `rdfaToTripleArray(data, baseUri)`
* Parses a RDFa document into an array of triples
* Parameters
  * data - the RDFa data
  * baseUri - the base URI used for any relative IRIs
* Returns an array of strings in the form `<subject> <predicate> <object> .`

# Example test cases
The following are a selection of example tests that demonstrate different features of the test harness and show 
various approaches to writing tests.

## protocol/content-negotiation/content-negotiation-turtle.feature
The purpose of this test is to confirm that a Turtle resource can be fetched as either JSON-LD or Turtle using content
negotiation.

```gherkin
Feature: Requests support content negotiation for Turtle resource

  Background: Create a turtle resource
    * def testContainer = createTestContainer()
    * def exampleTurtle = karate.readAsString('../fixtures/example.ttl')
    * def resource = testContainer.createChildResource('.ttl', exampleTurtle, 'text/turtle');
    * assert resource.exists()
    * def expected = RDFUtils.turtleToTripleArray(exampleTurtle, resource.getUrl())
    * configure headers = clients.alice.getAuthHeaders('GET', resource.getUrl())
    * url resource.getUrl()

  Scenario: Alice can read the TTL example as JSON-LD
    Given header Accept = 'application/ld+json'
    When method GET
    Then status 200
    And match header Content-Type contains 'application/ld+json'
    And match RDFUtils.jsonLdToTripleArray(JSON.stringify(response), resource.getUrl()) contains expected

  Scenario: Alice can read the TTL example as TTL
    Given header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match header Content-Type contains 'text/turtle'
    And match RDFUtils.turtleToTripleArray(response, resource.getUrl()) contains expected
```

The `Background` for this test:
* sets up a test container (which isn't yet instantiated)
* loads example Turtle data into a variable from a file
* puts this data into a resource inside the test container
* asserts that this resource exists (if it doesn't the test will stop at this point)
* convert the example data into an array of triples for later comparisons
* sets up the URL and authorization headers for the HTTP requests used in the scenarios 
  
Note that this `Background` is run for each `Scenario` so in reality 2 test files are created. That may seem 
inefficient, but it allows all scenarios to be run in parallel.

There are 2 scenarios based on this setup which perform the following steps:
* set an `Accept` header to get the resource as JSON-LD or as Turtle
* send a `GET` request for this resource
* confirm that the response code is `200`
* confirm the `Content-Type` header matches the requested type
* confirm that the response body, when converted to an array of triples contains the triples saved in the background
  setup

## protocol/wac-allow/access-Bob-W-public-RA.feature
The purpose of this test is to set up a resource with a combination of access controls and then confirm that the
WAC-Allow header reports the correct permissions.

```gherkin
Feature: The WAC-Allow header shows user and public access modes with Bob write and public read, append

  Background: Create test resource giving Bob write access and public read/append access
    * def setup =
    """
      function() {
        const testContainer = createTestContainer();
        const resource = testContainer.createChildResource('.ttl', karate.readAsString('../fixtures/example.ttl'), 'text/turtle');
        if (resource.exists()) {
          const acl = aclPrefix
            + createOwnerAuthorization(webIds.alice, resource.getUrl())
            + createBobAccessToAuthorization(webIds.bob, resource.getUrl(), 'acl:Write')
            + createPublicAccessToAuthorization(resource.getUrl(), 'acl:Read, acl:Append')
          karate.log('ACL: ' + acl);
          resource.setAcl(acl);
        }
        return resource;
      }
    """
    * def resource = callonce setup
    * assert resource.exists()
    * def resourceUrl = resource.getUrl()
    * url resourceUrl

  Scenario: There is an acl on the resource containing #bobAccessTo
    Given url resource.getAclUrl()
    And headers clients.alice.getAuthHeaders('GET', resource.getAclUrl())
    And header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match header Content-Type contains 'text/turtle'
    And match response contains 'bobAccessTo'

  Scenario: There is no acl on the parent
    Given url resource.getContainer().getAclUrl()
    And headers clients.alice.getAuthHeaders('HEAD', resource.getContainer().getAclUrl())
    And header Accept = 'text/turtle'
    When method HEAD
    Then status 404

  Scenario: Bob calls GET and the header shows RWA access for user, RA for public
    Given headers clients.bob.getAuthHeaders('GET', resourceUrl)
    When method GET
    Then status 200
    And match header WAC-Allow != null
    * def result = parseWacAllowHeader(responseHeaders)
    And match result.user contains only ['read', 'write', 'append']
    And match result.public contains only ['read', 'append']

  Scenario: Bob calls HEAD and the header shows RWA access for user, RA for public
    Given headers clients.bob.getAuthHeaders('HEAD', resourceUrl)
    When method HEAD
    Then status 200
    And match header WAC-Allow != null
    * def result = parseWacAllowHeader(responseHeaders)
    And match result.user contains only ['read', 'write', 'append']
    And match result.public contains only ['read', 'append']

  Scenario: Public calls GET and the header shows RA access for user and public
    When method GET
    Then status 200
    And match header WAC-Allow != null
    * def result = parseWacAllowHeader(responseHeaders)
    And match result.user contains only ['read', 'append']
    And match result.public contains only ['read', 'append']

  Scenario: Public calls HEAD and the header shows RA access for user and public
    When method HEAD
    Then status 200
    And match header WAC-Allow != null
    * def result = parseWacAllowHeader(responseHeaders)
    And match result.user contains only ['read', 'append']
    And match result.public contains only ['read', 'append']

```

The `Background` for this test:
* sets up a function which will be called once for the whole set of scenarios
  * creates a test container (which isn't yet instantiated)
  * creates a resource in this container using an example Turtle file
  * adds an ACL for the resource which grants Bob write access and the public read and append access - it logs this to
  make it visible in the reports
* use `callonce` to run the setup process once for all scenarios
* asserts that this resource exists (if it doesn't the test will stop at this point)
* sets up the URL for the HTTP requests used in most of the scenarios

The first 2 scenarios check the ACLs which could impact this test. The first fetches the resource's ACL and confirms
it contains the ACL document we just created. The second fetches the container's ACL to confirm there isn't one from 
which permissions could be inherited.

The subsequent scenarios have the following pattern:
* set up the authorization headers for requests from Bob but not for public requests
* send a `GET` or `HEAD` request for this resource
* confirm that the response code is `200`
* confirm that the WAC-Allow header exists
* parse the WAC-Allow header and save this to a variable
* confirm the expected set of permissions for each of Bob and the public user 

## protocol/writing-resource/containment.feature
The purpose of this test is to check that all containment triples are created on intemediate containers if a
resource is created on a path that doesn't exist using PUT or PATCH.

```gherkin
Feature: Creating a resource using PUT and PATCH must create intermediate containers

  Background: Set up clients and paths
    * def testContainer = createTestContainer()
    * def intermediateContainer = testContainer.generateChildContainer()
    * def resource = intermediateContainer.generateChildResource('.txt')

  Scenario: PUT creates a grandchild resource and intermediate containers
    * def resourceUrl = resource.getUrl()
    Given url resourceUrl
    And configure headers = clients.alice.getAuthHeaders('PUT', resourceUrl)
    And request "Hello"
    When method PUT
    Then assert responseStatus >= 200 && responseStatus < 300

    * def parentUrl = intermediateContainer.getUrl()
    Given url parentUrl
    And configure headers = clients.alice.getAuthHeaders('GET', parentUrl)
    And header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match intermediateContainer.parseMembers(response) contains resource.getUrl()

    * def grandParentUrl = testContainer.getUrl()
    Given url grandParentUrl
    And configure headers = clients.alice.getAuthHeaders('GET', grandParentUrl)
    And header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match testContainer.parseMembers(response) contains intermediateContainer.getUrl()

  Scenario: PATCH creates a grandchild resource and intermediate containers
    * def resourceUrl = resource.getUrl()
    Given url resourceUrl
    And configure headers = clients.alice.getAuthHeaders('PATCH', resourceUrl)
    And header Content-Type = "application/sparql-update"
    And request 'INSERT DATA { <#hello> <#linked> <#world> . }'
    When method PATCH
    Then assert responseStatus >= 200 && responseStatus < 300

    * def parentUrl = intermediateContainer.getUrl()
    Given url parentUrl
    And configure headers = clients.alice.getAuthHeaders('GET', parentUrl)
    And header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match intermediateContainer.parseMembers(response) contains resource.getUrl()

    * def grandParentUrl = testContainer.getUrl()
    Given url grandParentUrl
    And configure headers = clients.alice.getAuthHeaders('GET', grandParentUrl)
    And header Accept = 'text/turtle'
    When method GET
    Then status 200
    And match testContainer.parseMembers(response) contains intermediateContainer.getUrl()
```

The `Background` for this test:
* creates a resource as a grandchild of a test container (nothing is instantiated at this point)

Note that the 2 scenarios are independent as they each run the background steps, setting up their own test resource.

The pattern for the scenarios is based on making 3 HTTP requests. They each set up the URL and authorization headers
first, then the sequence is:
* send a `PUT` request to put data in this resource so it is actually created
* confirm that the response code a success code
* send a `GET` request for the resource's immediate container
* confirm that the response code is `200`
* parse the response and confirm that the resource is a member of this container  
* send a `GET` request for the resource's grandparent container (the original test container)
* confirm that the response code is `200`
* parse the response and confirm that the resource's immediate container is a member of this container

## web-access-control/protected-operation/read-resource-access-R.feature
The purpose of this test is to set up a resource with a combination of access controls and then confirm that the
WAC-Allow header reports the correct permissions.

```gherkin
Feature: Bob can only read an RDF resource to which he is only granted read access

  Background: Create test resource with read-only access for Bob
    * def setup =
    """
      function() {
        const testContainer = createTestContainer();
        const resource = testContainer.createChildResource('.ttl', karate.readAsString('../fixtures/example.ttl'), 'text/turtle');
        if (resource.exists()) {
          const acl = aclPrefix
            + createOwnerAuthorization(webIds.alice, resource.getUrl())
            + createBobAccessToAuthorization(webIds.bob, resource.getUrl(), 'acl:Read')
          karate.log('ACL: ' + acl);
          resource.setAcl(acl);
        }
        return resource;
      }
    """
    * def resource = callonce setup
    * assert resource.exists()
    * def resourceUrl = resource.getUrl()
    * url resourceUrl

  Scenario: Bob can read the resource with GET
    Given headers clients.bob.getAuthHeaders('GET', resourceUrl)
    When method GET
    Then status 200

  Scenario: Bob can read the resource with HEAD
    Given headers clients.bob.getAuthHeaders('HEAD', resourceUrl)
    When method HEAD
    Then status 200

  Scenario: Bob can read the resource with OPTIONS
    Given headers clients.bob.getAuthHeaders('OPTIONS', resourceUrl)
    When method OPTIONS
    Then status 204

  Scenario: Bob cannot PUT to the resource
    Given request '<> <http://www.w3.org/2000/01/rdf-schema#comment> "Bob replaced it." .'
    And headers clients.bob.getAuthHeaders('PUT', resourceUrl)
    And header Content-Type = 'text/turtle'
    When method PUT
    Then status 403

  Scenario: Bob cannot PATCH the resource
    Given request 'INSERT DATA { <> a <http://example.org/Foo> . }'
    And headers clients.bob.getAuthHeaders('PATCH', resourceUrl)
    And header Content-Type = 'application/sparql-update'
    When method PATCH
    Then status 403

  Scenario: Bob cannot POST to the resource
    Given request '<> <http://www.w3.org/2000/01/rdf-schema#comment> "Bob replaced it." .'
    And headers clients.bob.getAuthHeaders('POST', resourceUrl)
    And header Content-Type = 'text/turtle'
    When method POST
    Then status 403

  Scenario: Bob cannot DELETE the resource
    Given headers clients.bob.getAuthHeaders('DELETE', resourceUrl)
    When method DELETE
    Then status 403
```

The `Background` for this test:
* sets up a function which will be called once for the whole set of scenarios
  * creates a test container (which isn't yet instantiated)
  * creates a resource in this container using an example Turtle file
  * adds an ACL for the resource which grants Bob read access - it logs this to make it visible in the reports
* use `callonce` to run the setup process once for all scenarios
* asserts that this resource exists (if it doesn't the test will stop at this point)
* sets up the URL for the HTTP requests used in all of the scenarios

The scenarios then:
* set up the authorization headers for Bob to make each request
* send a request using each type of HTTP method
* confirm that the status codes for the `GET`, `HEAD` and `OPTIONS` requests are all `200`
* confirm that the status codes for `PUT`, `PATCH`, `POST` and `DELETE` requests are all `403`

# Specification annotations
**TODO**
How to annotate the spec, or use temporary data as alternative

# Test manifest
**TODO**
How to create the manifest files that link the spec requirements to the test cases