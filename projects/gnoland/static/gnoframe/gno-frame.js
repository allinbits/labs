class GnoFrame extends HTMLElement {
    constructor() {
        super();
        this.attachShadow({mode: 'open'});
        this.shadowRoot.innerHTML = `
            <style>
            /* Add your styles here */
            :host {
                display: block;
                width: 100%;
                height: 100%;
            }
            </style>
            <div id="gno-frame-container">
            <slot></slot>
            </div>
        `;
    }

    connectedCallback() {
        let data = {};
        try {
            data = JSON.parse(this.innerHTML);
        } catch (error) {
            console.error('Error parsing JSON:', error);
            return;
        }
        const gnoFrameId = '#'+data.frame+"-container"
        /* Add your html here */
        this.shadowRoot.querySelector(gnoFrameId).innerHTML = `
            <div>
            <h1>${data.name}</h1>
            <img src="${data.iconUrl}" alt="${data.name}">
            <p>${data.version}</p>
            <a href="${data.homeUrl}">Home</a>
            <img src="${data.imageUrl}" alt="${data.name}">
            <br />
            <br />
            <button>${data.buttonTitle}</button>
            </div>
        `;
        this.shadowRoot.querySelector('button').addEventListener('click', () => {
            const payload = {
                name: data.name,
                version: data.version,
                iconUrl: data.iconUrl,
                homeUrl: data.homeUrl,
                imageUrl: data.imageUrl,
                buttonTitle: data.buttonTitle,
                splashImageUrl: data.splashImageUrl,
                splashBackgroundColor: data.splashBackgroundColor,
                webhookUrl: data.webhookUrl,
            };
            Promise.resolve({ json: () => payload })
                .then(response => response.json())
                .then(data => console.log('Success:', data))
                .catch((error) => console.error('Error:', error));
        });
    }}

customElements.define('gno-frame', GnoFrame);