const directory = document.getElementById('controller-list');
const search = document.getElementById('controller-search');
const make = document.getElementById('controller-make');
const mapping = document.getElementById('controller-mapping');
const order = document.getElementById('controller-sort');
const statusLine = document.getElementById('controller-status');
const compare = new Intl.Collator('en-AU', { sensitivity: 'base', numeric: true }).compare;
const groups = Array.from(directory.children, section => ({
    section,
    name: section.dataset.make,
    list: section.querySelector('ul'),
    rows: Array.from(section.querySelectorAll('li'), element => ({
        element,
        name: element.querySelector('strong').textContent,
        mapping: element.querySelector('.mapping').textContent,
        text: (section.dataset.make + ' ' + element.textContent).toLowerCase()
    }))
}));
const total = groups.reduce((count, group) => count + group.rows.length, 0);

for (const group of groups) {
    make.add(new Option(group.name, group.name));
}
const mappings = new Set(groups.flatMap(group => group.rows.map(row => row.mapping)));
for (const name of [...mappings].sort(compare)) {
    mapping.add(new Option(name, name));
}

function sortGroups() {
    const groupDirection = order.value === 'manufacturer-desc' ? -1 : 1;
    const modelDirection = order.value === 'model-desc' ? -1 : 1;
    groups.sort((a, b) => groupDirection * compare(a.name, b.name));
    for (const group of groups) {
        group.rows.sort((a, b) => {
            const mappingOrder = order.value === 'mapping' ? compare(a.mapping, b.mapping) : 0;
            return mappingOrder || modelDirection * compare(a.name, b.name);
        });
        group.list.append(...group.rows.map(row => row.element));
        directory.append(group.section);
    }
}

function filterGroups() {
    const terms = search.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    let visible = 0;
    for (const group of groups) {
        let count = 0;
        for (const row of group.rows) {
            const matches = (!make.value || make.value === group.name)
                && (!mapping.value || mapping.value === row.mapping)
                && terms.every(term => row.text.includes(term));
            row.element.hidden = !matches;
            if (matches) count++;
        }
        group.section.hidden = count === 0;
        visible += count;
    }
    statusLine.textContent = visible === total ? total + ' controllers'
        : visible === 0 ? 'No controllers match. 0 of ' + total + ' controllers'
        : visible + ' of ' + total + ' controllers';
}

search.addEventListener('input', filterGroups);
make.addEventListener('change', filterGroups);
mapping.addEventListener('change', filterGroups);
order.addEventListener('change', sortGroups);
sortGroups();
filterGroups();
document.querySelector('[data-controller-tools]').hidden = false;
