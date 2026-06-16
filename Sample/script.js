document.getElementById("btn").addEventListener("click", () => {
  const output = document.getElementById("output");
  output.textContent = "JavaScript 도 정상 동작합니다! ⏱ " + new Date().toLocaleTimeString("ko-KR");
});
