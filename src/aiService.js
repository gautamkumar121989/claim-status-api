const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');

class AIService {
  constructor() {
    this.client = null;
    this.deploymentName = process.env.AZURE_OPENAI_DEPLOYMENT_NAME || 'gpt-35-turbo';
    this.initialize();
  }

  initialize() {
    if (!process.env.AZURE_OPENAI_ENDPOINT || !process.env.AZURE_OPENAI_API_KEY) {
      console.warn('Azure OpenAI not configured. AI summaries will be unavailable.');
      return;
    }

    try {
      this.client = new OpenAIClient(
        process.env.AZURE_OPENAI_ENDPOINT,
        new AzureKeyCredential(process.env.AZURE_OPENAI_API_KEY)
      );
      console.log('Azure OpenAI initialized successfully');
    } catch (error) {
      console.error('Failed to initialize Azure OpenAI:', error.message);
    }
  }

  async generateSummary(claim, notesText = '') {
    // Add input validation
    const MAX_NOTES_CHARS = 4000;
    const safeNotes = (notesText || '').slice(0, MAX_NOTES_CHARS);
    
    if (!this.client) {
      return {
        summary: `Claim ${claim.claimNumber} (${claim.type}) is ${claim.status} with estimate $${claim.estimatedAmount}.`,
        customerSummary: `Your claim ${claim.claimNumber} is currently ${claim.status}. We are reviewing the provided information.`,
        adjusterSummary: `Claim ${claim.claimNumber}: type=${claim.type}; status=${claim.status}; est=$${claim.estimatedAmount}; notesChars=${safeNotes.length}.`,
        nextStep: 'Review documentation and proceed to next workflow step',
        usageTokens: 0
      };
    }

    try {
      const system = 'You are an experienced insurance claims analyst. Generate natural language summaries as simple strings, not structured data. Return ONLY valid JSON with exactly 4 string fields.';
      const prompt = `Generate claim summaries as JSON with these exact keys: summary, customerSummary, adjusterSummary, nextStep.

Each value must be a single narrative string (not objects or arrays).

Claim Details:
- ID: ${claim.claimNumber}
- Type: ${claim.type}
- Status: ${claim.status}
- Amount: $${claim.estimatedAmount}
- Description: ${claim.description}

Notes: ${safeNotes || '(no notes available)'}

Return format example:
{
  "summary": "Brief professional overview of the claim in 1-2 sentences",
  "customerSummary": "Customer-friendly explanation of current status and what happens next",
  "adjusterSummary": "Technical assessment for adjusters with key details and next actions",
  "nextStep": "Specific next action to take on this claim"
}`;

      const response = await this.client.getChatCompletions(
        this.deploymentName,
        [
          { role: 'system', content: system },
          { role: 'user', content: prompt }
        ],
        { maxTokens: 500, temperature: 0.3 }
      );

      const raw = response.choices?.[0]?.message?.content?.trim() || '';
      
      // Extract JSON from response
      const jsonBlockMatch = raw.match(/\{[\s\S]*\}/);
      const candidate = jsonBlockMatch ? jsonBlockMatch[0] : raw;
      
      let parsed;
      try {
        parsed = JSON.parse(candidate);
        
        // Validate that we got string responses, not objects
        if (typeof parsed.summary === 'object' || typeof parsed.customerSummary === 'object') {
          throw new Error('AI returned structured data instead of strings');
        }
        
      } catch (parseError) {
        console.warn(`AI JSON parse failed: ${parseError.message}. Raw response: ${raw.slice(0, 200)}`);
        // Improved fallback with actual AI content
        const sentences = raw.split(/[.!?]+/).filter(s => s.trim().length > 10);
        parsed = {
          summary: sentences[0]?.trim() + '.' || 'AI summary generation failed',
          customerSummary: sentences[1]?.trim() + '.' || 'Please check back for updates on your claim',
          adjusterSummary: sentences[2]?.trim() + '.' || 'Manual review required for this claim',
          nextStep: sentences[3]?.trim() + '.' || 'Continue standard claim processing workflow'
        };
      }

      return {
        summary: String(parsed.summary || 'Summary unavailable'),
        customerSummary: String(parsed.customerSummary || parsed.summary || 'Customer summary unavailable'),
        adjusterSummary: String(parsed.adjusterSummary || parsed.summary || 'Adjuster summary unavailable'),
        nextStep: String(parsed.nextStep || 'No next step identified'),
        usageTokens: response.usage?.totalTokens || 0
      };
    } catch (error) {
      console.error(`AI service error - ErrorType: ${error.name}; Message: ${error.message}`);
      return {
        summary: 'Error generating AI summary. Please try again later.',
        customerSummary: 'We are still processing your claim. Please check back later.',
        adjusterSummary: 'AI generation failed; manual review required.',
        nextStep: 'Retry AI generation later',
        usageTokens: 0
      };
    }
  }
}

module.exports = new AIService();