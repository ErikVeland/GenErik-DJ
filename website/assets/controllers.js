const controllerList = document.querySelector('#controller-list');
if (controllerList) {
  const body = controllerList.tBodies[0];
  const rows = Array.from(body.rows);
  const search = document.querySelector('#controller-search');
  const make = document.querySelector('#controller-make');
  const mapping = document.querySelector("#controller-mapping");
  const order = document.querySelector('#controller-sort');
  const status = document.querySelector('#controller-status');
  const collator = new Intl.Collator('en-AU', { sensitivity: 'base', numeric: true });
  const cell = (row, index) => row.cells[index].textContent.trim();
  const manufacturers = new Set(rows.map(row => cell(row, 0)));
  for (const manufacturer of [...manufacturers].sort(collator.compare)) {
    make.add(new Option(manufacturer, manufacturer));
  }
  const mappings = new Set(rows.map(row => cell(row, 2)));
  for (const name of [...mappings].sort(collator.compare)) mapping.add(new Option(name, name));
  function updateControllers() {
    const terms = search.value.toLocaleLowerCase('en-AU').trim().split(/\s+/).filter(Boolean);
    const sortIndex = order.value === 'model' ? 1 : 0;
    const secondIndex = sortIndex === 0 ? 1 : 0;
    const sorted = [...rows].sort((a, b) =>
      collator.compare(cell(a, sortIndex), cell(b, sortIndex)) ||
      collator.compare(cell(a, secondIndex), cell(b, secondIndex)));
    let visible = 0;
    for (const row of sorted) {
      const haystack = Array.from(row.cells, item => item.textContent).join(' ').toLocaleLowerCase('en-AU');
      row.hidden = (make.value !== '' && cell(row, 0) !== make.value) ||
        (mapping.value !== "" && cell(row, 2) !== mapping.value) ||
        !terms.every(term => haystack.includes(term));
      if (!row.hidden) visible++;
    }
    body.append(...sorted);
    status.textContent = visible ? visible + (visible === 1 ? ' controller mapping' : ' controller mappings') : 'No controllers match.';
  }
  search.addEventListener('input', updateControllers);
  make.addEventListener('change', updateControllers);
  mapping.addEventListener("change", updateControllers);
  order.addEventListener('change', updateControllers);
  status.hidden = false;
  updateControllers();
  document.querySelector('[data-controller-tools]').hidden = false;
}
