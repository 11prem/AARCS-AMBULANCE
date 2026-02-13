# test_ai_questions.py - Test dynamic question generation
from ai_question_generator import AIQuestionGenerator

generator = AIQuestionGenerator(use_openai=False)

print("=" * 70)
print("🧪 TESTING AI-BASED DYNAMIC QUESTIONS")
print("=" * 70)

# Test different emergency types
emergency_types = ['accident', 'medical', 'fire', 'assault']

for emergency_type in emergency_types:
    print(f"\n{'='*70}")
    print(f"🚨 Emergency Type: {emergency_type.upper()}")
    print("="*70)
    
    questions = generator.get_initial_questions(emergency_type)
    
    print(f"\n📝 Questions for {emergency_type}:")
    for i, question in enumerate(questions, 1):
        print(f"   {i}. {question}")
    
    # Simulate conversation
    conversation = [
        {'role': 'agent', 'content': questions[0]},
        {'role': 'user', 'content': 'yes there are injuries'},
        {'role': 'agent', 'content': questions[1]}
    ]
    
    # Generate follow-up
    follow_up = generator.generate_next_question(emergency_type, conversation)
    print(f"\n🤖 AI Follow-up Question: {follow_up}")

print("\n" + "="*70)
print("✅ AI Question Generation Test Complete")
print("="*70)
