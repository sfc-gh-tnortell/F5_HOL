SUMMARY
You will create a Sales Semantic model, cortex search service and Agent based off the data from prompt.md

REQUIREMENTS

1. Create a schema called final this is where semantic models will be created and are the downstream result from the tables in prompt.md step 1.  
2. Create a cortex search service for the zoom transcripts.
3. Review F5 as a company and generate a list of questions a sales team would want to ask about their customers. 
4. Create a sales semantic view. The field names should match, again doesn't have to be all fields but should have a full account, opportunity, sales terrority, product sku and sales team information.  use the sample questions from step 3 to help structure the semantic view. This for sales, contracts, opportunity data only do not include telemetry or support data.
5. Create a cortex agent for snowflake cowork with the sales semantic view and the zoom cortex search service. There should also be a way to search for publicly avaialble informaiton about the compnay (linkedin posts, 10K or 10Q, major business deals etc.)


