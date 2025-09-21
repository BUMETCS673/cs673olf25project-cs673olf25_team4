import bannerImg from '../assets/beatmap-banner.png';

function Banner() {
  return (
    <header className="banner">
      <img src={bannerImg} alt="Beatmap banner" className="banner-img" />
    </header>
  );
}

export default Banner;
