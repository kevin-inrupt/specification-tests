@ignore
Feature: Check that Bob can only read RDF resource when he is authorized read only.
Background: Setup
  * def testContainer = createTestContainer()
  * testContainer.createChildResource('.txt', '', 'text/plain');



Scenario: Test 1.1 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('GET', requestUri)
  When method GET
  Then status 200



Scenario: Test 1.2 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('HEAD', requestUri)
  When method HEAD
  Then status 200



Scenario: Test 1.3 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('OPTIONS', requestUri)
  When method OPTIONS
  Then status 204



Scenario: Test 1.4 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('PUT', requestUri)
  And header Content-Type = 'text/turtle'
  And request '@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>. <> rdfs:comment "Bob replaced it." .     '
  When method PUT
  Then status 403



Scenario: Test 1.5 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('PATCH', requestUri)
  And header Content-Type = 'application/sparql-update'
  And request 'INSERT DATA { <> a <http://example.org/Foo> . }'
  When method PATCH
  Then status 403



Scenario: Test 1.6 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('PATCH', requestUri)
  And header Content-Type = 'application/sparql-update'
  And request 'INSERT DATA { <> a <http://example.org/Foo> . }'
  When method PATCH
  Then status 403



Scenario: Test 1.7 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('POST', requestUri)
  And header Content-Type = 'text/turtle'
  And request '@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>. <> rdfs:comment "Bob added this."     '
  When method POST
  Then status 403



Scenario: Test 1.8 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('DELETE', requestUri)
  When method DELETE
  Then status 403



Scenario: Test 1.9 on URL /alice_share_bob.ttl
  * def requestUri = testContainer.getUrl() + 'alice_share_bob.ttl'
  Given url requestUri
  And configure headers = clients.alice.getAuthHeaders('DAHU', requestUri)
  When method DAHU
  Then status 400


