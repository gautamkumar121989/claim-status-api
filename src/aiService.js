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
      const system = 'You are an experienced insurance claims analyst. Output ONLY valid JSON.';
      const prompt = `Return strict JSON with keys: summary, customerSummary, adjusterSummary, nextStep.

Claim:
ID: ${claim.claimNumber}
Type: ${claim.type}
Status: ${claim.status}
EstimatedAmount: $${claim.estimatedAmount}
Description: ${claim.description}

Notes (${safeNotes.length} chars):
${safeNotes || '(no notes)'}
`;

      const response = await this.client.getChatCompletions(
        this.deploymentName,
        [
          { role: 'system', content: system },
          { role: 'user', content: prompt }
        ],
        { maxTokens: 450, temperature: 0.3 }
      );

      const raw = response.choices?.[0]?.message?.content?.trim() || '';
      
      // Improved JSON parsing
      const jsonBlockMatch = raw.match(/\{[\s\S]*\}/);
      const candidate = jsonBlockMatch ? jsonBlockMatch[0] : raw;
      
      let parsed;
      try {
        parsed = JSON.parse(candidate);
      } catch {
        // Fallback parsing
        parsed = {
          summary: raw.slice(0, 400),
          customerSummary: raw.slice(0, 400),
          adjusterSummary: raw.slice(0, 400),
          nextStep: 'Review claim details'
        };
      }

      return {
        summary: parsed.summary || 'Summary unavailable',
        customerSummary: parsed.customerSummary || parsed.summary || 'Customer summary unavailable',
        adjusterSummary: parsed.adjusterSummary || parsed.summary || 'Adjuster summary unavailable',
        nextStep: parsed.nextStep || 'No next step identified',
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