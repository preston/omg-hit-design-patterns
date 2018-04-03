Author:	Preston Lee
Email:	preston.lee@prestonlee.com
Title:	Health IT *MN Implementation Cookbook
Subtitle: Model deployment in platform-specific CDS.

*A work-in-progress, with most recent feedback from the March 20th, 2018 OMG Healthcare DTF meeting.*

```
#!/bin/bash
# To convert this into other formats with pandoc...

# Word:
pandoc -f markdown_mmd -t docx --toc -o index.docx index.md

# PDF:
pandoc -f markdown_mmd -t pdf --toc -o index.docx index.md

# ePub:
pandoc -f markdown_mmd -t epub --toc -o index.epub index.md

# HTML:
pandoc -f markdown_mmd -t html --toc -o index.html index.md
```

# Health IT (HIT) *MN Implementation Cookbook

Clinical decision support (CDS) is an inately integrated activity: the notion of "support" implying an integration outside the boundaries of a given function. HIT architectures designed for modular development, such as in the case of SOAs, call for CDS processes to operate across data and computation authorities. Even monolithic EHRs benefit from internal logical partitioning within the system and databases, if only for the sanity of development teams.

BPM execution may be described in similar form. A model may be developed by a small team of SMEs, but is ultimately useless to execute only in the vacuum of a non-production environment against mock data. In planning to incorporate \*MN execution as the engine of clinical enterprise processes and decisions, we have outlined a number of reference patterns specifically catering to HIT-specific standards that enterprise architects are likely to encounter.

As with the rest of this field guide, these patterns are not prescriptive. Given the heterogeneity and vendor-specific nature of HIT environments it is implausible to offer universally-applicable blueprints, however, we suggest accounting for a number of critical factors in any workflow execution context. They represent distilled baseline approaches for local adaptation based on present-day standards of broad interest in HIT, and are scope constrained to architectural situations specific to healthcare.

## Common Concerns
Some concerns span all integration contexts. Before applying any such pattern, consider the following.

### Scope of Model State
The primary subject of each model instance may be centered on an individual, but is likely not a patient or practitioner model themselves. E.g., the contextual data and metadata surrounding patient's record, especially those triggering the start of a process or case, is just as important to executing as the patient record itself. While it may be easiest to understand models centered around only a noun -- such as "patient" -- a useful model is more likely to track state of a activity of the noun, in a triggering context, such as "patient checkin for appointment". The broader contextual information is likely helpful to externalized CDS tasks.

### Unintended Interruptions
In BPMs, consider that models need the ability to handle greatly varying input cases that may warrant disturbing a prescriptive business process at an inopportune time, such as when about to create an automated order for a condition that has suddenly been marked as resolved from an out-of-band encounter. When this occurs, you may need specialty events for *cancelling* or *compensating* for activities that changed data but are no longer appropriate, and/or guards for revalidating that input conditions are indeed still valid if a significant period of time has past such that stale data issue come into play. Thus, an execution context needs to have fully cleaned up after itself in all end states, and needs the ability handle these operations in coordination with external systems in such a way that you safely expect the unexpected. *Undoing* an activity in distributed transactional systems is generally more complicated than *doing* in the first place.

And as mentioned earlier in the guide, a highly gatewayed BPM with more error flows than happy paths is likely indicative of a situation better modeled using a CMM and/or DM.

### Optimistic Execution & Race Conditions
HIT is a highly non-deterministic domain that can apply \*MN models in combination. While CMMs with parallel BPMs make intuitive sense for many non-prescriptive workflows, note that there is no inherent concept of "locking" a patient record via mutex or semaphore, such that only one of many potentially parallel activities may execute at once. In cases when the output of a parallel activity A may influence the input of a another parallel activity B, the input state of B (and thus the output of B) becomes dependent on whether A is able to write its output state before B receives its input state.

A similar situation may arrise in additional parallel activities C and D, where *both* C and D update a common data element without regard (or even knowledge) of each other. This "last one wins" scenario results in the output of the *first* activity effectively being discarded when subsequently overwritten by D. In worst cases, this results in corruption of the common record with a union of C's and D's output, which may or may not be semantically coherent, syntactically valid, or safe, such as when erroneous resultant order sets are generated. 

The generalized form of this problem is known as a *race condition*, where a dependent result is dependant on a "race" between independent factors.  This presents a serious patient safety issue in cases where a *decision* of consequence is made during activity B. It is notoriously difficult to validate that race conditions do **not** exist in a model/system, since symptoms are completely dependent on the exact timing of asynchronous, non-deterministic events. In practice, cases tend to arise sporadically after deployment and in unreproducible ways.

In addition to patient safety issues related to record locking, consider the execution environment in the context of any computationally optimistic system, and the consequences of doing so. Case in point: When modeling parallel activities for real-world *execution* using common data objects  -- not just for knowledge representation and sharing purposes -- carefully consider the effects of concurrent access and timelines across parallel tasks.

### Services, Scripts, and the Double Curly Braces Problem

The "curly braces problem" is the clinical informatics term for imprecise, non-computable binding of locale-specific dependencies within an otherwise standards-compliant document, tracing back to an HL7 standard known as Arden syntax.

In clinical \*MN integration, the same class of problem arises when an operation must be made outside of the model as a design-time *separation of concerns* decision, but in doing so introduces a non-computable integration into the model. The natural places for this to occur is in service and script tasks. Script tasks are opaque to the \*MN engine, and thus have no gaurantees of compatibility across environments. Service tasks, such as REST calls made in a destination SOA, have the similar drawback that only the *structural* compatibilty is declared as part of the task definition. Behavioral modeling of the external dependency is not declared as part of the interface integration. Reliance on HIT-specific concept refinements, such as FHIR profiles, is outside the scope of \*MN models, and thus introduces potential for semantic mismatch across execution environments, even if static compatibility validations pass successfully.

When integrating service APIs, especially from a general-purpose modeling tool that has no special HIT considerations, provide ample documentation on the local requirements that either cannot be captured by the model, or are unlikely to translate in a reproducible, computable way.  

Script tasks, in particular, are a complete interoperability gamble, as no \*MN standard defines a minimum set of languages that will be supported. Other than being in "mime-type format", the BPMN 2 specification does not further constrain the value of the "scriptFormat" attribute, nor provide guidance on how language versions or runtime requirements should be specified. This introduces a number of practical compatibilty problems with service tasks:

1. Popular engines are often based on the Open Source KIE family of libraries. These implementations are likely to support a degree of JSR-223-compatible scripting languages, but (a) this is a highly platform-specific feature, and (b) the notion of a JSR itself is foreign to those outside the Java community.
2. Even with an assumption of common runtimes across environments, underlying versions and available libraries are not guaranteed, and MIME types, while flexible, are generally (but not always) used for structural or syntactic purposes only, such as "application/javascript" or "application/ecmascript". It is far less common to see resource version numbers embedded in the MIME, and not appropriate to embed dependencies in this string.
3.  General-purpose runtimes will not have support for CDS-specific languages such as GELLO, as is the case with out-of-the-box, KIE-based engines.

Further, a negative quality of layered specifications with strict encapsulation is an inability to produce *globally* optimized processes. As the \*MN standards are decoupled from concrete implementations, no design-time assumptions can be made as to the timeliness of either task type, nor the efficiencies and time complexities that they exhibit.

For all the above reasons, we discourage the use of script tasks as a workflow-oriented form of the curly braces problem. Service task integrations will be covered in specific design patterns. 

### Logging and Traceability
Healthcare is a highly regulated domain requiring large numbers of individuals to hold accountability for life-critical decisions. A net effect of this distributed (yet regulated) approach is the need for meticulous record keeping, not only for individuals, but system-level accesses and decisions as well, such as those from \*MN runtimes. In most domains, and especially in healthcare, it is important to maintain a reasonable level of logging. Audit records, while often troublesome to implement, are important to:

* Verifying compliance with policy.
* Routine reporting.
* Identifying internal errors.
* Tracing flows across different systems.
* Closing the feedback loop to future care and system improvements by providing raw longitudinal data on usage analysis, though **do not blindly log PHI data elements** unless the environment is specifically designed to do so.
* Responding to forensic needs before, during and after a security incident.

The domain-specific needs for logging and audit trails coincide with emergent HIT issues with tracing operations throughout the entirety of a SOA. As individual services are broken into smaller, atomic services, popularly known as "microservices", the total number of services and integration points grows, potentially exponentially in the theoretic worst case. In all SOAs, and most importantly in µSOAs, it is critical to trace a function, such as a user "click" or a business process instance state change, to all the downstream effects that cross service boundaries. To do so, implement support for vendor-neutral distributed tracing, such as [OpenTracing](http://opentracing.io), to integrated external services.

Outside HIT benefits, all SOAs can benefits from unified logging, and \*MN engines should be fully integrated with local capabilities. 

### Participant Identity and Access Management
Do not assume that individual actors within a workflow have the same level of data access. Workflows do not have inherent knowledge of the access restrictions placed upon its users. For example, a front desk administrator may have limited access to patient location to visitor routing, call handling and support purposes, but does not need detailed PHI. In other words, **the presence of a data object or information dependency does not imply it is available to a given participant** that may happen to be prevent during a referencing task of the workflow.

### Complex Patient Decisions
CDS is commonly envisioned to be modular: where logic and other knowledge of significant complexity are not “baked in” to a single workflow, but authoritatively represented in an external knowledge management system. Further, DMN’s Friendly Enough Expression Language is not intended to provide exhaustively long decision tables that exceed the ability of a human to cognitively understand them, such as the case of machine learning models.

In these cases, it is recommended to use either an alternative scripting language, an externalized service implementation accessed via API call, or combination of the two. Language availability is an implementation-specific feature. Camunda, for example, allows for any JSR–223-compliant language. Note, however, that alternative scripting languages introduce the “double curly braces problem” into your model, discussed above, potentially effecting the interoperability characteristics of your model. Consider the pro and cons of this approach before introducing additional languages and/or external service calls.

### Service Level Agreements (SLAs) of Integrated Services

TODO Discuss availability, performance etc.

## Solution Recipes
This section provides concrete solution templates for integrating a *\MN runtime with well-known HIT standards.

### SMART-on-FHIR (SoF)
SoF is the prevailing HIT mechanism for using OAuth 2 and OpenID Connect (OIDC) for launching a software clients against a separate FHIR-based backend. It is essentially just OIDC with further refinement for specifying authorization "scopes" for FHIR resources and passing launch parameters.  A SoF application "launch" is a well-defined and documented process. SoF, being primarily concerned with initialization of a client app, is largely orthogonal to \*MN, but with several important consideration.

OAuth 2, and thus SoF, does not specify a way for authorizing access to multiple backend services simultaneously. SoF applications are thus designed under the general assumption that a single FHIR resource server is the sole integration point of the software. For a client to "kick off" a workflow -- such as upon sucessful SoF launch, patient selection, or order placement -- a triggering event must be recieved by the \*MN runtime.

#### Simple Client/Server Architecture
In a "typical" SoF application where the client and server are essentially the only two relevent software actors after launch, interactions with the \*MN runtime should likely originate from the *client* side, for several reasons:

* FHIR is a platform specification, and implementors are expected to only support and expose the capabilities necessary for a given services scope. That is, while FHIR does have event and messaging mechanisms, it is unlikely that a FHIR-centric backend service will support hooking into \*MN as part of its scoped resource management functions.
* Authorization is sketchy, at best. In CDS Hooks, discussed in a separate recipe, a bearer token credential may be passed to a backend service across the wire but direct access to FHIR resources, but **it is extremely bad security practice for a user to disclose his/her private credentials for an external party to masquarade on their behalf**. In other words, a FHIR server should not be expected to manage the security credentials of a user/client, and should always have access to its own that distinctly identify it is a _service_ making requests, not a user agent.

Thus, to tie a simple SoF application to a \*MN engine, integrate it directly and using a separate OAuth 2 login flows. This is a bit awkard in that it doubles the number of browser redirects, but is more secure since the user is obtaining separate access tokens for both servers, and at no point is one service masquerading as the SoF client.

#### Complex Client/Server Architecture
TODO Write
In a more sophisticated SoF scenario where...

### Synchronous CDS Hooks Invocation
TODO Discuss the "Hello, Patient" example, as demo, and more real-world examples of explicit invocation.

### Asynchronous Implicit Invocation
TODO Discussing implicitly _triggered_ CDS as part of \*MN, as opposed to explicitly invoked cases. 

### HL7 Decision Support Service (DSS)
TODO

### Terminology Resolution
TODO Discuss FHIR Terminology, CTS2 etc for lookups, equivalence, and subsumption testing.

The conceptually simplest terminology-related functions are (1) interactive text-based searches for user selection of appropriate term/code, and (2) lookups for known codes, but these are not the only functions of a terminology service. A workflow requiring dynamic expansion of a value set or class-based filtering will need a service external to the workflow engine, optimized for these specific functions via specialized indexes and caches. One such example is FHIR’s ValueSet $expand operation.
  
### HL7 Infobutton Manager and User-Initiated CDS
TODO Discuss how these can be integrated, if desired.

### HL7 v2 and v3
TODO Yup.

### CQL, GELLO, and CDS-Specific Languages
TODO Discuss if desired.

### Machine Learning, NLP, and Resource-Intensive Activities

TODO Elaborate on service integration with long-running synchronous services, and provide guidelines on FEEL complexity.