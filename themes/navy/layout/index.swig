<div class="home-cover">
     {{ partial('partial/header') }}
    <div class="site-specific-menu">
        <p>
            <a class="site-name" href="{{ url_for('/') }}">Keycard</a>
            <a class="specific-nav-link" href="{{ url_for('/api') }}"><span>API</span></a>
        </p>
    </div>
    <div class="intro">
        <h1>An Open Source Card For Everything, Evereywhere</h1>
        <p>We’re bringing crypto closer to real life with an open source Java card and API that anyone can use, anywhere.</p>
        <div class="intro-buttons">
            <a class="button button--main" href="mailto:keycard@status.im">CONTACT US</a>
        </div>
    </div>
</div>
<div class="home-wrap">
    <div class="wrap">
        <div class="forward-text">
            <h2>Keeping You Safe</h2>
            <p>We care deeply about open source software and decentralization. Since this technology is so new, mainstream adoption will take time. Our goal is to hasten this process by incubating projects that share the same organizational values as Status.</p> 
            <p>We incubate startups on a rolling basis and participating projects span a wide variety of areas - from scaling solutions and base layer protocols to end-user ÐApps.</p> 
        </div>
        <div class="forward-img">
            <img src="{{ url_for('img/incubate_beaker.svg') }}" />
        </div>
    </div>

    <div class="wrap">
        <div class="feature">
            <img class="funding-img" src="{{ url_for('img/funding.svg') }}" />
            <h3>Funding</h3>
            <p>We offer standard pre-seed funding in exchange for equity and tokens (where applicable). Funding for later-stage projects is also possible on a case-by-case basis.</p>
        </div>
        <div class="feature">
            <img class="tech-img" src="{{ url_for('img/technical_support.svg') }}" />
            <h3>Technical Support</h3>
            <p>Projects will have access to our large technical team with deep expertise across the full stack.</p>
        </div>
        <div class="feature">
            <img class="legal-img" src="{{ url_for('img/legal_reg.svg') }}" />
            <h3>Legal and Regulatory Compliance</h3>
            <p>Experienced legal and financial advisors will support you as you navigate the legalities, recruit your team, and perfect your organisational structure.</p>
        </div>
        <div class="feature">
            <img class="marketing-img" src="{{ url_for('img/marketing_comm.svg') }}" />
            <h3>Marketing and Communication</h3>
            <p>We have expertise in branding, product positioning, content planning, and building open source communities.</p>
        </div>
        <div class="feature">
            <img class="mentor-img" src="{{ url_for('img/mentorship.svg') }}" />
            <h3>Mentorship</h3>
            <p>Projects will have access to our volunteer mentor network who can provide coaching on the various aspects of building a Web3 startup.</p>
        </div>
        <div class="feature">
            <img class="product-img" src="{{ url_for('img/product_design.svg') }}" />
            <h3>Product Design</h3>
            <p>UX and UI are critical to product adoption. We rely on insights from extensive user testing, and focus on making things useful and usable.</p>
        </div>
    </div>
    
</div>