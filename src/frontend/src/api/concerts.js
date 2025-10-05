export async function fetchRecommendations(userInput) {
  try {
    const response = await fetch(
      `/concerts/recommendations?user_input=${encodeURIComponent(userInput)}`
    );

    if (!response.ok) {
      throw new Error("Failed to fetch recommendations");
    }

    const data = await response.json();
    console.log("Fetched recommendations:", data);
    return data;
  } catch (error) {
    console.error("Error fetching recommendations:", error);
    return { recommendations: [] };
  }
}
